package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
)

type application struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
}

type identityCache map[string]application

type aliasesFlag []string

func (a *aliasesFlag) String() string { return strings.Join(*a, ",") }

func (a *aliasesFlag) Set(value string) error {
	*a = append(*a, value)
	return nil
}

type favoritesFlag []string

func (f *favoritesFlag) String() string { return strings.Join(*f, ",") }

func (f *favoritesFlag) Set(value string) error {
	*f = append(*f, value)
	return nil
}

type settings struct {
	Favorites []string `json:"favorites"`
	Providers struct {
		Applications struct {
			Entrypoints map[string]struct {
				Alias string `json:"alias"`
			} `json:"entrypoints"`
		} `json:"applications"`
	} `json:"providers"`
}

func main() {
	if len(os.Args) < 2 {
		fail("usage: app-identity <refresh|lookup|settings> [options]")
	}

	var err error
	switch os.Args[1] {
	case "refresh":
		err = refresh(os.Args[2:])
	case "lookup":
		err = lookup(os.Args[2:])
	case "settings":
		err = writeSettings(os.Args[2:])
	default:
		err = fmt.Errorf("unknown command %q", os.Args[1])
	}
	if err != nil {
		fail("%v", err)
	}
}

func refresh(args []string) error {
	flags := flag.NewFlagSet("refresh", flag.ContinueOnError)
	cachePath := flags.String("cache", defaultCachePath(), "application identity cache path")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("refresh accepts no positional arguments")
	}
	if runtime.GOOS != "darwin" {
		return fmt.Errorf("application bundle scanning is supported only on macOS")
	}

	identities, err := discoverApplications()
	if err != nil {
		return err
	}
	data, err := marshalJSON(identities)
	if err != nil {
		return err
	}
	changed, err := writeIfChanged(*cachePath, data)
	if err != nil {
		return err
	}
	printChange(changed)
	return nil
}

func lookup(args []string) error {
	flags := flag.NewFlagSet("lookup", flag.ContinueOnError)
	cachePath := flags.String("cache", defaultCachePath(), "application identity cache path")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("usage: app-identity lookup [--cache PATH] KEY")
	}
	identities, err := readCache(*cachePath, false)
	if err != nil {
		return err
	}
	key := flags.Arg(0)
	app, ok := identities[key]
	if !ok {
		return fmt.Errorf("application key %q is not in the identity cache; refresh it after installing the app", key)
	}
	fmt.Println(app.BundleID)
	return nil
}

func writeSettings(args []string) error {
	flags := flag.NewFlagSet("settings", flag.ContinueOnError)
	cachePath := flags.String("cache", defaultCachePath(), "application identity cache path")
	outputPath := flags.String("output", "", "Vicinae JSON override path")
	allowMissing := flags.Bool("allow-missing", false, "omit aliases whose apps are not present in the cache")
	var aliases aliasesFlag
	var favorites favoritesFlag
	flags.Var(&aliases, "alias", "Vicinae alias mapping in alias=application-key form; repeatable")
	flags.Var(&favorites, "favorite", "Vicinae favorite entrypoint ID; repeatable")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *outputPath == "" {
		return fmt.Errorf("settings requires --output PATH")
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("settings accepts aliases and favorites only through --alias and --favorite")
	}

	identities, err := readCache(*cachePath, *allowMissing)
	if err != nil {
		return err
	}
	config, err := makeSettings(identities, aliases, favorites, *allowMissing)
	if err != nil {
		return err
	}
	data, err := marshalJSON(config)
	if err != nil {
		return err
	}
	changed, err := writeIfChanged(*outputPath, data)
	if err != nil {
		return err
	}
	printChange(changed)
	return nil
}

func makeSettings(identities identityCache, aliases, favorites []string, allowMissing bool) (settings, error) {
	result := settings{Favorites: []string{"clipboard:history"}}
	favoriteSet := map[string]struct{}{"clipboard:history": {}}
	for _, favorite := range favorites {
		if favorite == "" {
			return settings{}, fmt.Errorf("favorite entrypoint ID cannot be empty")
		}
		if _, exists := favoriteSet[favorite]; !exists {
			result.Favorites = append(result.Favorites, favorite)
			favoriteSet[favorite] = struct{}{}
		}
	}
	result.Providers.Applications.Entrypoints = make(map[string]struct {
		Alias string `json:"alias"`
	})
	seenAliases := make(map[string]struct{}, len(aliases))

	for _, mapping := range aliases {
		alias, key, ok := strings.Cut(mapping, "=")
		if !ok || alias == "" || key == "" {
			return settings{}, fmt.Errorf("invalid --alias %q: expected alias=application-key", mapping)
		}
		if _, exists := seenAliases[alias]; exists {
			return settings{}, fmt.Errorf("duplicate alias %q", alias)
		}
		seenAliases[alias] = struct{}{}

		app, exists := identities[key]
		if !exists {
			if allowMissing {
				continue
			}
			return settings{}, fmt.Errorf("application key %q for alias %q is missing from the identity cache", key, alias)
		}
		if previous, exists := result.Providers.Applications.Entrypoints[app.BundleID]; exists {
			return settings{}, fmt.Errorf("aliases %q and %q resolve to the same application %q", previous.Alias, alias, app.BundleID)
		}
		appFavorite := "applications:" + app.BundleID
		if _, exists := favoriteSet[appFavorite]; !exists {
			result.Favorites = append(result.Favorites, appFavorite)
			favoriteSet[appFavorite] = struct{}{}
		}
		result.Providers.Applications.Entrypoints[app.BundleID] = struct {
			Alias string `json:"alias"`
		}{Alias: alias}
	}
	return result, nil
}

func discoverApplications() (identityCache, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("find home directory: %w", err)
	}
	roots := []string{"/Applications", "/System/Applications", filepath.Join(home, "Applications")}
	byBundleID := make(map[string]application)

	for _, root := range roots {
		if _, err := os.Stat(root); errors.Is(err, os.ErrNotExist) {
			continue
		} else if err != nil {
			return nil, fmt.Errorf("inspect application root %q: %w", root, err)
		}

		err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
			if walkErr != nil {
				return nil
			}
			if path == root {
				return nil
			}
			if !strings.HasSuffix(entry.Name(), ".app") {
				return nil
			}

			isSymlink := entry.Type()&os.ModeSymlink != 0
			if !entry.IsDir() && !isSymlink {
				return nil
			}

			bundleID, name, err := readBundleIdentity(filepath.Join(path, "Contents", "Info.plist"))
			if err == nil {
				if name == "" {
					name = strings.TrimSuffix(entry.Name(), ".app")
				}
				if _, exists := byBundleID[bundleID]; !exists {
					byBundleID[bundleID] = application{Name: name, BundleID: bundleID}
				}
			}
			if entry.IsDir() {
				return filepath.SkipDir
			}
			return nil
		})
		if err != nil {
			return nil, fmt.Errorf("scan application root %q: %w", root, err)
		}
	}

	return assignKeys(byBundleID), nil
}

func readBundleIdentity(path string) (bundleID, name string, err error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", "", err
	}
	if !bytes.HasPrefix(data, []byte("bplist00")) {
		bundleID, name, err = parseXMLPlist(data)
		if err == nil && bundleID != "" {
			return bundleID, name, nil
		}
	}
	return readWithPlistBuddy(path)
}

func parseXMLPlist(data []byte) (bundleID, name string, err error) {
	decoder := xml.NewDecoder(bytes.NewReader(data))
	var pendingKey string
	for {
		token, tokenErr := decoder.Token()
		if errors.Is(tokenErr, io.EOF) {
			break
		}
		if tokenErr != nil {
			return "", "", tokenErr
		}
		start, ok := token.(xml.StartElement)
		if !ok {
			continue
		}

		switch start.Name.Local {
		case "key":
			if err := decoder.DecodeElement(&pendingKey, &start); err != nil {
				return "", "", err
			}
		case "string":
			var value string
			if err := decoder.DecodeElement(&value, &start); err != nil {
				return "", "", err
			}
			switch pendingKey {
			case "CFBundleIdentifier":
				bundleID = value
			case "CFBundleName", "CFBundleDisplayName":
				if name == "" {
					name = value
				}
			}
			pendingKey = ""
		case "plist", "dict", "array":
			continue
		default:
			pendingKey = ""
			if err := decoder.Skip(); err != nil {
				return "", "", err
			}
		}
		if bundleID != "" && name != "" {
			return bundleID, name, nil
		}
	}
	if bundleID == "" {
		return "", "", fmt.Errorf("CFBundleIdentifier is missing")
	}
	return bundleID, name, nil
}

func readWithPlistBuddy(path string) (string, string, error) {
	bundleID, idErr := exec.Command("/usr/libexec/PlistBuddy", "-c", "Print :CFBundleIdentifier", path).Output()
	if idErr != nil {
		bundleID, idErr = exec.Command("/usr/bin/plutil", "-extract", "CFBundleIdentifier", "raw", "-o", "-", path).Output()
	}
	if idErr != nil {
		return "", "", fmt.Errorf("read CFBundleIdentifier from %s: %w", path, idErr)
	}

	name, nameErr := exec.Command("/usr/libexec/PlistBuddy", "-c", "Print :CFBundleName", path).Output()
	if nameErr != nil {
		name, _ = exec.Command("/usr/bin/plutil", "-extract", "CFBundleName", "raw", "-o", "-", path).Output()
	}
	return strings.TrimSpace(string(bundleID)), strings.TrimSpace(string(name)), nil
}

var slugPattern = regexp.MustCompile(`[^A-Za-z0-9]+`)

func slug(value string) string {
	value = strings.ToLower(strings.Trim(slugPattern.ReplaceAllString(value, "-"), "-"))
	if value == "" {
		return "application"
	}
	return value
}

func assignKeys(byBundleID map[string]application) identityCache {
	bundleIDs := make([]string, 0, len(byBundleID))
	for bundleID := range byBundleID {
		bundleIDs = append(bundleIDs, bundleID)
	}
	sort.Strings(bundleIDs)

	result := make(identityCache, len(bundleIDs))
	for _, bundleID := range bundleIDs {
		parts := strings.Split(bundleID, ".")
		key := slug(parts[len(parts)-1])
		if _, exists := result[key]; exists {
			key = slug(bundleID)
		}
		base := key
		for suffix := 2; ; suffix++ {
			if _, exists := result[key]; !exists {
				break
			}
			key = fmt.Sprintf("%s-%d", base, suffix)
		}
		result[key] = byBundleID[bundleID]
	}
	return result
}

func readCache(path string, allowMissing bool) (identityCache, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) && allowMissing {
		return identityCache{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read application identity cache %q: %w", path, err)
	}
	var identities identityCache
	if err := json.Unmarshal(data, &identities); err != nil {
		return nil, fmt.Errorf("parse application identity cache %q: %w", path, err)
	}
	if identities == nil {
		identities = identityCache{}
	}
	return identities, nil
}

func writeIfChanged(path string, data []byte) (bool, error) {
	current, err := os.ReadFile(path)
	if err == nil && bytes.Equal(current, data) {
		return false, nil
	}
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return false, fmt.Errorf("read existing file %q: %w", path, err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, fmt.Errorf("create directory for %q: %w", path, err)
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".app-identity-*.tmp")
	if err != nil {
		return false, fmt.Errorf("create temporary file for %q: %w", path, err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return false, fmt.Errorf("set permissions on %q: %w", temporaryPath, err)
	}
	if _, err := temporary.Write(data); err != nil {
		temporary.Close()
		return false, fmt.Errorf("write %q: %w", temporaryPath, err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return false, fmt.Errorf("sync %q: %w", temporaryPath, err)
	}
	if err := temporary.Close(); err != nil {
		return false, fmt.Errorf("close %q: %w", temporaryPath, err)
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return false, fmt.Errorf("replace %q: %w", path, err)
	}
	return true, nil
}

func marshalJSON(value any) ([]byte, error) {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}

func printChange(changed bool) {
	if changed {
		fmt.Println("changed")
	} else {
		fmt.Println("unchanged")
	}
}

func defaultCachePath() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base, _ = os.UserCacheDir()
	}
	return filepath.Join(base, "nix-config", "app-identities.json")
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "app-identity: "+format+"\n", args...)
	os.Exit(1)
}
