package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
)

type manifest struct {
	Taps     []tap
	Formulae []string
	Casks    []string
	MASApps  []masApp
}

type tap struct {
	Name    string `json:"name"`
	Trusted bool   `json:"trusted"`
}

type masApp struct {
	Name string `json:"name"`
	ID   int64  `json:"id"`
}

type plan struct {
	Brewfile       string   `json:"brewfile"`
	Prefix         string   `json:"prefix"`
	MissingTaps    []tap    `json:"missingTaps"`
	MissingFormula []string `json:"missingFormulae"`
	MissingCasks   []string `json:"missingCasks"`
	MissingMASApps []masApp `json:"missingMASApps"`
}

type inventory struct {
	formulae map[string]bool
	casks    map[string]bool
	taps     map[string]bool
	masApps  map[int64]bool
}

func main() {
	if len(os.Args) < 2 {
		fatal(errors.New("usage: brew-state-sync <plan|sync> [--brewfile FILE] [options]"))
	}
	command := os.Args[1]
	if command != "plan" && command != "sync" {
		fatal(fmt.Errorf("unknown command %q; expected plan or sync", command))
	}

	args, err := parseFlags(command, os.Args[2:])
	if err != nil {
		fatal(err)
	}

	declarations, err := readBrewfile(args.brewfile)
	if err != nil {
		fatal(err)
	}
	if command == "sync" {
		if err := requireExecutable(args.brew, "Homebrew"); err != nil {
			fatal(err)
		}
		if err := configureBrewEnvironment(args.autoUpdate, args.upgrade); err != nil {
			fatal(err)
		}
		if args.autoUpdate {
			if err := run(args.brew, "update"); err != nil {
				fatal(err)
			}
		}
		if err := bootstrapMAS(args, declarations); err != nil {
			fatal(err)
		}
	}

	state, err := readInventory(context.Background(), args, declarations)
	if err != nil {
		fatal(err)
	}
	changes := compare(args.brewfile, args.prefix, declarations, state)

	if command == "plan" {
		writePlan(changes, args.jsonOutput)
		return
	}
	if err := apply(changes, declarations, args); err != nil {
		fatal(err)
	}
}

type commandFlags struct {
	brewfile   string
	prefix     string
	brew       string
	mas        string
	autoUpdate bool
	upgrade    bool
	jsonOutput bool
}

func parseFlags(command string, argv []string) (commandFlags, error) {
	flags := flag.NewFlagSet(command, flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	result := commandFlags{}
	flags.StringVar(&result.brewfile, "brewfile", defaultBrewfile(), "Brewfile to read (defaults to HOMEBREW_BUNDLE_FILE or ~/.config/homebrew/Brewfile)")
	flags.StringVar(&result.prefix, "prefix", "/opt/homebrew", "Homebrew installation prefix")
	flags.StringVar(&result.brew, "brew", "", "Homebrew executable (defaults to PREFIX/bin/brew)")
	flags.StringVar(&result.mas, "mas", "", "mas executable (defaults to PREFIX/bin/mas)")
	flags.BoolVar(&result.autoUpdate, "auto-update", false, "run brew update before comparing and syncing")
	flags.BoolVar(&result.upgrade, "upgrade", false, "upgrade declared formulae, casks, and MAS apps")
	flags.BoolVar(&result.jsonOutput, "json", false, "print a JSON plan (plan command only)")
	if err := flags.Parse(argv); err != nil {
		return commandFlags{}, err
	}
	if flags.NArg() != 0 {
		return commandFlags{}, errors.New("unexpected positional arguments")
	}
	if command == "plan" && (result.autoUpdate || result.upgrade) {
		return commandFlags{}, errors.New("--auto-update and --upgrade are only valid with sync")
	}
	if command == "sync" && result.jsonOutput {
		return commandFlags{}, errors.New("--json is only valid with plan")
	}
	if result.brewfile == "" {
		return commandFlags{}, errors.New("could not determine Brewfile path; pass --brewfile")
	}
	if result.brew == "" {
		result.brew = filepath.Join(result.prefix, "bin", "brew")
	}
	if result.mas == "" {
		result.mas = filepath.Join(result.prefix, "bin", "mas")
	}
	return result, nil
}

var (
	brewfileEntry = regexp.MustCompile(`^(tap|brew|cask)\s+("(?:\\.|[^"\\])*")(?:,\s*trusted:\s*(true|false))?\s*$`)
	masEntry      = regexp.MustCompile(`^mas\s+("(?:\\.|[^"\\])*"),\s*id:\s*([0-9]+)\s*$`)
)

func defaultBrewfile() string {
	if path := os.Getenv("HOMEBREW_BUNDLE_FILE"); path != "" {
		return path
	}
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return ""
		}
		configHome = filepath.Join(home, ".config")
	}
	return filepath.Join(configHome, "homebrew", "Brewfile")
}

func readBrewfile(path string) (manifest, error) {
	file, err := os.Open(path)
	if err != nil {
		return manifest{}, fmt.Errorf("open Brewfile: %w", err)
	}
	defer file.Close()

	var result manifest
	scanner := bufio.NewScanner(file)
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if match := brewfileEntry.FindStringSubmatch(line); match != nil {
			name, err := strconv.Unquote(match[2])
			if err != nil {
				return manifest{}, fmt.Errorf("Brewfile line %d: invalid quoted name: %w", lineNo, err)
			}
			switch match[1] {
			case "tap":
				trusted := match[3] == "true"
				result.Taps = append(result.Taps, tap{Name: name, Trusted: trusted})
			case "brew":
				if match[3] != "" {
					return manifest{}, fmt.Errorf("Brewfile line %d: trusted is only valid for tap", lineNo)
				}
				result.Formulae = append(result.Formulae, name)
			case "cask":
				if match[3] != "" {
					return manifest{}, fmt.Errorf("Brewfile line %d: trusted is only valid for tap", lineNo)
				}
				result.Casks = append(result.Casks, name)
			}
			continue
		}
		if match := masEntry.FindStringSubmatch(line); match != nil {
			name, err := strconv.Unquote(match[1])
			if err != nil {
				return manifest{}, fmt.Errorf("Brewfile line %d: invalid MAS app name: %w", lineNo, err)
			}
			id, err := strconv.ParseInt(match[2], 10, 64)
			if err != nil {
				return manifest{}, fmt.Errorf("Brewfile line %d: invalid MAS app ID: %w", lineNo, err)
			}
			result.MASApps = append(result.MASApps, masApp{Name: name, ID: id})
			continue
		}
		return manifest{}, fmt.Errorf("Brewfile line %d: unsupported syntax: %s", lineNo, line)
	}
	if err := scanner.Err(); err != nil {
		return manifest{}, fmt.Errorf("read Brewfile: %w", err)
	}
	if err := validateManifest(result); err != nil {
		return manifest{}, err
	}
	return result, nil
}

func validateManifest(value manifest) error {
	seen := map[string]bool{}
	check := func(kind, name string) error {
		if strings.TrimSpace(name) == "" {
			return fmt.Errorf("Brewfile contains an empty %s name", kind)
		}
		key := kind + ":" + name
		if seen[key] {
			return fmt.Errorf("Brewfile contains duplicate %s %q", kind, name)
		}
		seen[key] = true
		return nil
	}
	for _, value := range value.Taps {
		if !strings.Contains(value.Name, "/") {
			return fmt.Errorf("tap name %q must be user/repository", value.Name)
		}
		if err := check("tap", value.Name); err != nil {
			return err
		}
	}
	for _, name := range value.Formulae {
		if err := check("formula", name); err != nil {
			return err
		}
	}
	for _, name := range value.Casks {
		if err := check("cask", name); err != nil {
			return err
		}
	}
	for _, app := range value.MASApps {
		if app.ID <= 0 {
			return fmt.Errorf("MAS app %q has invalid ID %d", app.Name, app.ID)
		}
		if err := check("MAS app", strconv.FormatInt(app.ID, 10)); err != nil {
			return err
		}
	}
	return nil
}

func readInventory(ctx context.Context, args commandFlags, declared manifest) (inventory, error) {
	var (
		formulae   map[string]bool
		casks      map[string]bool
		taps       map[string]bool
		masApps    map[int64]bool
		formulaErr error
		caskErr    error
		tapErr     error
		masAppsErr error
	)

	var scans sync.WaitGroup
	scanCount := 3
	if len(declared.MASApps) > 0 {
		scanCount++
	}
	scans.Add(scanCount)
	go func() {
		defer scans.Done()
		formulae, formulaErr = directoryNames(filepath.Join(args.prefix, "Cellar"))
	}()
	go func() {
		defer scans.Done()
		casks, caskErr = directoryNames(filepath.Join(args.prefix, "Caskroom"))
	}()
	go func() {
		defer scans.Done()
		taps, tapErr = installedTaps(filepath.Join(args.prefix, "Library", "Taps"))
	}()
	if len(declared.MASApps) > 0 {
		go func() {
			defer scans.Done()
			masApps, masAppsErr = installedMASApps(ctx, args.mas)
		}()
	}
	scans.Wait()
	if err := errors.Join(formulaErr, caskErr, tapErr, masAppsErr); err != nil {
		return inventory{}, err
	}
	return inventory{formulae: formulae, casks: casks, taps: taps, masApps: masApps}, nil
}

func bootstrapMAS(args commandFlags, declared manifest) error {
	if len(declared.MASApps) == 0 {
		return nil
	}
	if requireExecutable(args.mas, "mas") == nil {
		return nil
	}
	var masFormula string
	for _, formula := range declared.Formulae {
		if formulaToken(formula) == "mas" {
			masFormula = formula
			break
		}
	}
	if masFormula == "" {
		return fmt.Errorf("MAS apps are declared but mas is unavailable and no mas formula is declared")
	}
	formulae, err := directoryNames(filepath.Join(args.prefix, "Cellar"))
	if err != nil {
		return err
	}
	if formulae[formulaToken(masFormula)] {
		return fmt.Errorf("mas formula is present but executable is unavailable at %s", args.mas)
	}
	if err := requireExecutable(args.brew, "Homebrew"); err != nil {
		return err
	}
	return run(args.brew, "install", "--formula", masFormula)
}

func compare(brewfilePath, prefix string, declared manifest, installed inventory) plan {
	result := plan{
		Brewfile:       brewfilePath,
		Prefix:         prefix,
		MissingTaps:    []tap{},
		MissingFormula: []string{},
		MissingCasks:   []string{},
		MissingMASApps: []masApp{},
	}
	for _, value := range declared.Taps {
		if !installed.taps[tapPath(value.Name)] {
			result.MissingTaps = append(result.MissingTaps, value)
		}
	}
	for _, name := range declared.Formulae {
		if !installed.formulae[formulaToken(name)] {
			result.MissingFormula = append(result.MissingFormula, name)
		}
	}
	for _, name := range declared.Casks {
		if !installed.casks[caskToken(name)] {
			result.MissingCasks = append(result.MissingCasks, name)
		}
	}
	for _, app := range declared.MASApps {
		if !installed.masApps[app.ID] {
			result.MissingMASApps = append(result.MissingMASApps, app)
		}
	}
	sort.Slice(result.MissingTaps, func(i, j int) bool { return result.MissingTaps[i].Name < result.MissingTaps[j].Name })
	sort.Strings(result.MissingFormula)
	sort.Strings(result.MissingCasks)
	sort.Slice(result.MissingMASApps, func(i, j int) bool { return result.MissingMASApps[i].ID < result.MissingMASApps[j].ID })
	return result
}

func apply(changes plan, declared manifest, args commandFlags) error {
	if len(changes.MissingTaps)+len(changes.MissingFormula)+len(changes.MissingCasks)+len(changes.MissingMASApps) == 0 {
		if !args.upgrade {
			fmt.Println("Homebrew is synchronized; no changes needed.")
			return nil
		}
	} else {
		fmt.Printf("Homebrew sync: %d taps, %d formulae, %d casks, %d MAS apps missing.\n",
			len(changes.MissingTaps), len(changes.MissingFormula), len(changes.MissingCasks), len(changes.MissingMASApps))
	}
	if err := requireExecutable(args.brew, "Homebrew"); err != nil {
		return err
	}

	for _, value := range changes.MissingTaps {
		if err := run(args.brew, "tap", value.Name); err != nil {
			return err
		}
	}
	for _, value := range declared.Taps {
		if value.Trusted && tapNeeded(value.Name, changes) {
			if err := run(args.brew, "trust", "--tap", value.Name); err != nil {
				return err
			}
		}
	}
	if len(changes.MissingFormula) > 0 {
		if err := run(args.brew, append([]string{"install", "--formula"}, changes.MissingFormula...)...); err != nil {
			return err
		}
	}
	if len(changes.MissingCasks) > 0 {
		if err := run(args.brew, append([]string{"install", "--cask"}, changes.MissingCasks...)...); err != nil {
			return err
		}
	}
	if len(changes.MissingMASApps) > 0 {
		if err := requireExecutable(args.mas, "mas"); err != nil {
			return err
		}
		ids := make([]string, 0, len(changes.MissingMASApps))
		for _, app := range changes.MissingMASApps {
			ids = append(ids, strconv.FormatInt(app.ID, 10))
		}
		if err := run(args.mas, append([]string{"install"}, ids...)...); err != nil {
			return err
		}
	}
	if args.upgrade {
		if err := upgradeDeclared(args.brew, args.mas, declared); err != nil {
			return err
		}
	}
	return nil
}

func tapNeeded(name string, changes plan) bool {
	for _, value := range changes.MissingTaps {
		if value.Name == name {
			return true
		}
	}
	for _, value := range changes.MissingFormula {
		if hasTapPrefix(value, name) {
			return true
		}
	}
	for _, value := range changes.MissingCasks {
		if hasTapPrefix(value, name) {
			return true
		}
	}
	return false
}

func hasTapPrefix(name, tapName string) bool {
	return strings.HasPrefix(name, tapName+"/")
}

func upgradeDeclared(brew, mas string, declared manifest) error {
	if len(declared.Formulae) > 0 {
		if err := run(brew, append([]string{"upgrade", "--formula"}, declared.Formulae...)...); err != nil {
			return err
		}
	}
	if len(declared.Casks) > 0 {
		if err := run(brew, append([]string{"upgrade", "--cask"}, declared.Casks...)...); err != nil {
			return err
		}
	}
	if len(declared.MASApps) > 0 {
		ids := make([]string, 0, len(declared.MASApps))
		for _, app := range declared.MASApps {
			ids = append(ids, strconv.FormatInt(app.ID, 10))
		}
		if err := run(mas, append([]string{"upgrade"}, ids...)...); err != nil {
			return err
		}
	}
	return nil
}

func configureBrewEnvironment(autoUpdate, upgrade bool) error {
	if err := os.Setenv("HOMEBREW_NO_ENV_HINTS", "1"); err != nil {
		return err
	}
	if !autoUpdate {
		if err := os.Setenv("HOMEBREW_NO_AUTO_UPDATE", "1"); err != nil {
			return err
		}
	}
	if !upgrade {
		if err := os.Setenv("HOMEBREW_NO_INSTALL_UPGRADE", "1"); err != nil {
			return err
		}
	}
	return nil
}

func run(executable string, args ...string) error {
	command := exec.Command(executable, args...)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	command.Stdin = os.Stdin
	fmt.Printf("+ %s %s\n", executable, strings.Join(args, " "))
	if err := command.Run(); err != nil {
		return fmt.Errorf("run %s %s: %w", executable, strings.Join(args, " "), err)
	}
	return nil
}

func requireExecutable(path, name string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("%s executable unavailable at %s: %w", name, path, err)
	}
	if info.IsDir() || info.Mode()&0o111 == 0 {
		return fmt.Errorf("%s path is not executable: %s", name, path)
	}
	return nil
}

func directoryNames(root string) (map[string]bool, error) {
	entries, err := os.ReadDir(root)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]bool{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", root, err)
	}
	names := make(map[string]bool, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			names[entry.Name()] = true
		}
	}
	return names, nil
}

func installedTaps(root string) (map[string]bool, error) {
	users, err := os.ReadDir(root)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]bool{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", root, err)
	}
	result := map[string]bool{}
	for _, user := range users {
		if !user.IsDir() {
			continue
		}
		repos, err := os.ReadDir(filepath.Join(root, user.Name()))
		if err != nil {
			return nil, fmt.Errorf("read taps for %s: %w", user.Name(), err)
		}
		for _, repo := range repos {
			if repo.IsDir() {
				result[user.Name()+"/"+strings.TrimPrefix(repo.Name(), "homebrew-")] = true
			}
		}
	}
	return result, nil
}

func installedMASApps(ctx context.Context, mas string) (map[int64]bool, error) {
	if err := requireExecutable(mas, "mas"); err != nil {
		return nil, fmt.Errorf("MAS apps are declared but %w", err)
	}
	command := exec.CommandContext(ctx, mas, "list")
	output, err := command.Output()
	if err != nil {
		return nil, fmt.Errorf("list installed MAS apps: %w", err)
	}
	result := map[int64]bool{}
	for _, line := range strings.Split(string(output), "\n") {
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		id, err := strconv.ParseInt(fields[0], 10, 64)
		if err != nil {
			return nil, fmt.Errorf("could not parse mas list output line %q", line)
		}
		result[id] = true
	}
	return result, nil
}

func formulaToken(name string) string {
	parts := strings.Split(name, "/")
	return parts[len(parts)-1]
}

func caskToken(name string) string {
	parts := strings.Split(name, "/")
	return parts[len(parts)-1]
}

func tapPath(name string) string {
	parts := strings.SplitN(name, "/", 2)
	if len(parts) != 2 {
		return name
	}
	return parts[0] + "/" + strings.TrimPrefix(parts[1], "homebrew-")
}

func writePlan(result plan, asJSON bool) {
	if asJSON {
		if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
			fatal(err)
		}
		return
	}
	printGroup := func(title string, values []string) {
		fmt.Printf("%s: ", title)
		if len(values) == 0 {
			fmt.Println("none")
			return
		}
		fmt.Println()
		for _, value := range values {
			fmt.Printf("  - %s\n", value)
		}
	}
	fmt.Printf("Homebrew local-state plan\nBrewfile: %s\nPrefix: %s\n", result.Brewfile, result.Prefix)
	tapNames := make([]string, 0, len(result.MissingTaps))
	for _, value := range result.MissingTaps {
		trust := ""
		if value.Trusted {
			trust = " (trusted)"
		}
		tapNames = append(tapNames, value.Name+trust)
	}
	printGroup("Missing taps", tapNames)
	printGroup("Missing formulae", result.MissingFormula)
	printGroup("Missing casks", result.MissingCasks)
	masNames := make([]string, 0, len(result.MissingMASApps))
	for _, app := range result.MissingMASApps {
		masNames = append(masNames, fmt.Sprintf("%s (id %d)", app.Name, app.ID))
	}
	printGroup("Missing MAS apps", masNames)
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "brew-state-sync:", err)
	os.Exit(2)
}
