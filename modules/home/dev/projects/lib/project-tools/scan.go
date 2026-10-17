package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/charlievieth/fastwalk"
	git "github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
	"golang.org/x/sync/errgroup"
)

var skipDirs = map[string]bool{
	".git": true, ".direnv": true, ".local": true, ".archify": true,
	".sandbox": true, ".playwright-cli": true, ".playwright-mcp": true,
	".zcode": true, ".serena": true, ".superpowers": true,
	".venv": true, "venv": true, "node_modules": true, "target": true,
	"dist": true, "build": true, "output": true, ".next": true,
	".turbo": true, ".cache": true, "coverage": true,
}

var projectMarkers = []string{
	"flake.nix", "go.mod", "Cargo.toml", "pyproject.toml", "package.json",
	"pnpm-workspace.yaml", "justfile", "Makefile", "mise.toml",
}

type scanner struct {
	ctx          context.Context
	root         string
	now          time.Time
	inactiveDays int
	workers      int
	gitSlots     chan struct{}
}

type repositorySet struct {
	mu    sync.Mutex
	roots []string
	seen  map[string]bool
}

func parallelMap[T, R any](ctx context.Context, items []T, workers int, fn func(context.Context, T) (R, error)) ([]R, error) {
	results := make([]R, len(items))
	group, ctx := errgroup.WithContext(ctx)
	group.SetLimit(min(workers, len(items)))
	for index, item := range items {
		index, item := index, item
		group.Go(func() error {
			result, err := fn(ctx, item)
			if err == nil {
				results[index] = result
			}
			return err
		})
	}
	return results, group.Wait()
}

func defaultWorkers() int {
	workers := runtime.NumCPU()
	if workers > 8 {
		return 8
	}
	if workers < 1 {
		return 1
	}
	return workers
}

func (s *scanner) addRepositoryMarker(parent string, found *repositorySet) error {
	add := func(path string) {
		path = canonical(path)
		found.mu.Lock()
		defer found.mu.Unlock()
		if !found.seen[path] {
			found.seen[path] = true
			found.roots = append(found.roots, path)
		}
	}
	repo, err := git.PlainOpenWithOptions(parent, &git.PlainOpenOptions{DetectDotGit: true})
	if err == nil {
		worktree, worktreeErr := repo.Worktree()
		if worktreeErr == nil {
			add(worktree.Filesystem.Root())
			return s.ctx.Err()
		}
	}
	if output, cliErr := s.gitOutput(parent, "rev-parse", "--show-toplevel"); cliErr == nil {
		add(strings.TrimSpace(string(output)))
	}
	return s.ctx.Err()
}

type worktree struct {
	Path           string `json:"path"`
	Branch         string `json:"branch,omitempty"`
	Head           string `json:"head,omitempty"`
	Detached       bool   `json:"detached,omitempty"`
	Bare           bool   `json:"bare,omitempty"`
	Prunable       bool   `json:"prunable,omitempty"`
	Locked         bool   `json:"locked,omitempty"`
	Available      bool   `json:"available"`
	Inspectable    bool   `json:"inspectable"`
	Dirty          *bool  `json:"dirty"`
	ChangedEntries *int   `json:"changedEntries"`
	Primary        bool   `json:"primary"`
	OwnerRepo      string `json:"ownerRepo,omitempty"`
}

type remote struct {
	Name      string   `json:"name"`
	FetchURLs []string `json:"fetchUrls"`
	PushURLs  []string `json:"pushUrls"`
}

type repository struct {
	Path                  string     `json:"path"`
	AbsolutePath          string     `json:"absolutePath"`
	Branch                *string    `json:"branch"`
	Head                  *string    `json:"head"`
	Upstream              *string    `json:"upstream"`
	UnpushedCommits       *int       `json:"unpushedCommits"`
	CommitsBehindUpstream *int       `json:"commitsBehindUpstream"`
	HasCommits            bool       `json:"hasCommits"`
	Remotes               []remote   `json:"remotes"`
	LastCommitAt          *string    `json:"lastCommitAt"`
	LastFileActivityAt    *string    `json:"lastFileActivityAt"`
	ActivityAgeDays       *int       `json:"activityAgeDays"`
	Dirty                 bool       `json:"dirty"`
	ChangedEntries        int        `json:"changedEntries"`
	Worktrees             []worktree `json:"-"`
	Findings              []string   `json:"findings"`
}

type candidate struct {
	Path    string   `json:"path"`
	Signals []string `json:"signals"`
	Finding string   `json:"finding"`
}

type container struct {
	Path            string   `json:"path"`
	RepositoryCount int      `json:"repositoryCount"`
	Repositories    []string `json:"repositories"`
}

type finding struct {
	Path    string   `json:"path"`
	Reasons []string `json:"reasons"`
}

type report struct {
	SchemaVersion           int          `json:"schemaVersion"`
	Root                    string       `json:"root"`
	ScannedAt               string       `json:"scannedAt"`
	InactiveAfterDays       int          `json:"inactiveAfterDays"`
	Repositories            []repository `json:"repositories"`
	UninitializedCandidates []candidate  `json:"uninitializedCandidates"`
	Containers              []container  `json:"containers"`
	Worktrees               []worktree   `json:"worktrees"`
	Findings                []finding    `json:"findings"`
	WorktreeCount           int          `json:"worktreeCount"`
}

func (s *scanner) gitOutput(dir string, args ...string) ([]byte, error) {
	if s.gitSlots != nil {
		select {
		case s.gitSlots <- struct{}{}:
		case <-s.ctx.Done():
			return nil, s.ctx.Err()
		}
		defer func() { <-s.gitSlots }()
	}
	return exec.CommandContext(s.ctx, "git", append([]string{"-C", dir}, args...)...).Output()
}

func canonical(path string) string {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		resolved, _ = filepath.Abs(path)
	}
	return filepath.Clean(resolved)
}

func expandUserPath(path string) string {
	if path != "~" && !strings.HasPrefix(path, "~/") {
		return path
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return path
	}
	if path == "~" {
		return home
	}
	return filepath.Join(home, path[2:])
}

func rel(path, root string) string {
	value, err := filepath.Rel(root, path)
	if err != nil {
		return path
	}
	if value == "" {
		return "."
	}
	return value
}

func (s *scanner) findRepositories() ([]string, error) {
	found := repositorySet{seen: map[string]bool{}}
	config := fastwalk.Config{NumWorkers: s.workers, Sort: fastwalk.SortLexical}
	err := fastwalk.Walk(&config, s.root, func(path string, entry fs.DirEntry, walkErr error) error {
		if err := s.ctx.Err(); err != nil {
			return err
		}
		if walkErr != nil {
			return nil
		}
		if entry.IsDir() && entry.Name() == ".git" {
			if err := s.addRepositoryMarker(filepath.Dir(path), &found); err != nil {
				return err
			}
			return fastwalk.SkipDir
		}
		if !entry.IsDir() && entry.Name() == ".git" {
			if err := s.addRepositoryMarker(filepath.Dir(path), &found); err != nil {
				return err
			}
		}
		if entry.IsDir() && path != s.root {
			name := entry.Name()
			if skipDirs[name] || strings.HasPrefix(name, ".nix-derivation") {
				return fastwalk.SkipDir
			}
		}
		return nil
	})
	sort.Slice(found.roots, func(i, j int) bool {
		return strings.ToLower(found.roots[i]) < strings.ToLower(found.roots[j])
	})
	return found.roots, err
}

func (s *scanner) parseWorktrees(repoPath string) ([]worktree, error) {
	output, err := s.gitOutput(repoPath, "worktree", "list", "--porcelain", "-z")
	if err != nil {
		if s.ctx.Err() != nil {
			return nil, s.ctx.Err()
		}
		return nil, nil
	}
	return parseWorktreePorcelain(output, repoPath, s.ctx, s.workers, s.gitOutput)
}

func parseWorktreePorcelain(output []byte, repoPath string, ctx context.Context, workers int, gitOutput func(string, ...string) ([]byte, error)) ([]worktree, error) {
	var result []worktree
	current := worktree{}
	flush := func() {
		if current.Path != "" {
			path := current.Path
			if filepath.IsAbs(path) {
				current.Path = filepath.Clean(path)
			} else {
				current.Path = filepath.Join(repoPath, path)
			}
			current.Available = isDirectory(current.Path)
			current.Primary = canonical(current.Path) == canonical(repoPath)
			result = append(result, current)
		}
		current = worktree{}
	}
	for _, line := range strings.Split(string(output), "\x00") {
		if line == "" {
			flush()
			continue
		}
		key, value, found := strings.Cut(line, " ")
		if !found {
			key, value = line, ""
		}
		switch key {
		case "worktree":
			current.Path = value
		case "branch":
			current.Branch = strings.TrimPrefix(value, "refs/heads/")
		case "HEAD":
			current.Head = value
		case "detached":
			current.Detached = true
		case "bare":
			current.Bare = true
		case "prunable":
			current.Prunable = true
		case "locked":
			current.Locked = true
		}
	}
	flush()
	return parallelMap(ctx, result, workers, func(ctx context.Context, tree worktree) (worktree, error) {
		if !tree.Available {
			return tree, nil
		}
		status, statusErr := gitOutput(tree.Path, "status", "--porcelain=v1", "--untracked-files=normal")
		if statusErr != nil {
			if ctx.Err() != nil {
				return tree, ctx.Err()
			}
			return tree, nil
		}
		tree.Inspectable = true
		count := len(nonEmptyLines(string(status)))
		dirty := count > 0
		tree.Dirty = &dirty
		tree.ChangedEntries = &count
		return tree, nil
	})
}

func isDirectory(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func nonEmptyLines(value string) []string {
	var lines []string
	for _, line := range strings.Split(value, "\n") {
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

func pythonISOTime(value time.Time) string {
	value = value.Round(time.Microsecond)
	if value.Nanosecond() == 0 {
		return value.Format("2006-01-02T15:04:05-07:00")
	}
	return value.Format("2006-01-02T15:04:05.000000-07:00")
}

func (s *scanner) fileActivity(repo string) *time.Time {
	output, err := s.gitOutput(repo, "ls-files", "--cached", "--others", "--exclude-standard", "-z")
	if err != nil {
		return nil
	}
	var newest time.Time
	for _, name := range strings.Split(string(output), "\x00") {
		if name == "" {
			continue
		}
		info, err := os.Lstat(filepath.Join(repo, filepath.FromSlash(name)))
		if err == nil && info.ModTime().After(newest) {
			newest = info.ModTime()
		}
	}
	if newest.IsZero() {
		if info, err := os.Stat(repo); err == nil {
			newest = info.ModTime()
		}
	}
	if newest.IsZero() {
		return nil
	}
	utc := newest.UTC()
	return &utc
}

func sanitizeRemoteURL(value string) string {
	if !strings.Contains(value, "://") {
		return value
	}
	parsed, err := url.Parse(value)
	if err != nil {
		return "<invalid-url-redacted>"
	}
	parsed.User = nil
	parsed.RawQuery = ""
	parsed.Fragment = ""
	return parsed.String()
}

func (s *scanner) repositoryRemotes(repoPath string) []remote {
	output, err := s.gitOutput(repoPath, "remote")
	if err != nil {
		return []remote{}
	}
	names := nonEmptyLines(string(output))
	remotes := make([]remote, 0, len(names))
	for _, name := range names {
		item := remote{Name: name, FetchURLs: []string{}, PushURLs: []string{}}
		for index, query := range [][]string{{"remote", "get-url", "--all", name}, {"remote", "get-url", "--push", "--all", name}} {
			urls, queryErr := s.gitOutput(repoPath, query...)
			if queryErr != nil {
				continue
			}
			var values []string
			for _, value := range nonEmptyLines(string(urls)) {
				values = append(values, sanitizeRemoteURL(strings.TrimSpace(value)))
			}
			if index == 1 {
				item.PushURLs = values
			} else {
				item.FetchURLs = values
			}
		}
		remotes = append(remotes, item)
	}
	return remotes
}

func (s *scanner) latestCommitAt(repoPath string) *string {
	output, err := s.gitOutput(repoPath, "log", "-1", "--format=%cI", "--all")
	if err != nil {
		return nil
	}
	parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(string(output)))
	if err != nil {
		return nil
	}
	stamp := pythonISOTime(parsed)
	return &stamp
}

func (s *scanner) inspectRepository(path string) (repository, error) {
	result := repository{Path: rel(path, s.root), AbsolutePath: path, Worktrees: []worktree{}, Findings: []string{}}
	if marker, err := os.Stat(filepath.Join(path, ".git")); err == nil && !marker.IsDir() {
		// Linked worktrees rely on gitdir indirection; go-git's support is
		// partial, so use Git's worktree-aware view for these repositories.
		return s.inspectRepositoryCLI(path)
	}
	repo, err := git.PlainOpenWithOptions(path, &git.PlainOpenOptions{DetectDotGit: true})
	if err != nil {
		// Git accepts extension/config combinations that go-git rejects. Keep
		// those repositories usable through the system Git CLI.
		return s.inspectRepositoryCLI(path)
	}
	head, headErr := repo.Head()
	if headErr != nil && !errors.Is(headErr, plumbing.ErrReferenceNotFound) {
		return s.inspectRepositoryCLI(path)
	}
	if headErr == nil {
		hash := head.Hash().String()
		result.Head = &hash
		if head.Name().IsBranch() {
			branch := head.Name().Short()
			result.Branch = &branch
		}
		result.HasCommits = true
	} else {
		// An unborn branch has no resolvable HEAD, but Git still reports its name.
		branchOutput, _ := s.gitOutput(path, "branch", "--show-current")
		if branch := strings.TrimSpace(string(branchOutput)); branch != "" {
			result.Branch = &branch
		}
	}
	return s.completeRepository(result, path)
}

func (s *scanner) inspectRepositoryCLI(path string) (repository, error) {
	result := repository{Path: rel(path, s.root), AbsolutePath: path, Worktrees: []worktree{}, Findings: []string{}}
	branchOutput, _ := s.gitOutput(path, "branch", "--show-current")
	branch := strings.TrimSpace(string(branchOutput))
	if branch != "" {
		result.Branch = &branch
	}
	headOutput, headErr := s.gitOutput(path, "rev-parse", "--verify", "HEAD")
	if headErr == nil {
		head := strings.TrimSpace(string(headOutput))
		result.Head = &head
		result.HasCommits = true
	}
	return s.completeRepository(result, path)
}

func (s *scanner) completeRepository(result repository, path string) (repository, error) {
	result.Remotes = s.repositoryRemotes(path)
	result.LastCommitAt = s.latestCommitAt(path)
	statusOutput, statusErr := s.gitOutput(path, "status", "--porcelain=v1", "--untracked-files=normal")
	if statusErr == nil {
		result.ChangedEntries = len(nonEmptyLines(string(statusOutput)))
		result.Dirty = result.ChangedEntries > 0
	}
	activity := s.fileActivity(path)
	if activity != nil {
		stamp := pythonISOTime(*activity)
		result.LastFileActivityAt = &stamp
	}
	latest := time.Time{}
	if result.LastCommitAt != nil {
		latest, _ = time.Parse(time.RFC3339Nano, *result.LastCommitAt)
	}
	if activity != nil && activity.After(latest) {
		latest = *activity
	}
	if !latest.IsZero() {
		age := int(s.now.Sub(latest).Hours() / 24)
		result.ActivityAgeDays = &age
	}
	result.Upstream, result.UnpushedCommits, result.CommitsBehindUpstream = s.upstreamCounts(path)
	worktrees, err := s.parseWorktrees(path)
	if err != nil {
		return repository{}, err
	}
	result.Worktrees = worktrees
	anyDirtyWorktree := false
	for _, tree := range result.Worktrees {
		if tree.Dirty != nil && *tree.Dirty {
			anyDirtyWorktree = true
		}
	}
	if !result.HasCommits {
		result.Findings = append(result.Findings, "no-commits")
	}
	if result.Dirty {
		result.Findings = append(result.Findings, "uncommitted-changes")
	} else if anyDirtyWorktree {
		result.Findings = append(result.Findings, "dirty-worktree")
	}
	if result.UnpushedCommits != nil && *result.UnpushedCommits > 0 {
		result.Findings = append(result.Findings, "unpushed-commits")
	}
	for _, tree := range result.Worktrees {
		if tree.Prunable {
			result.Findings = append(result.Findings, "prunable-worktree")
			break
		}
	}
	if result.ActivityAgeDays != nil && *result.ActivityAgeDays >= s.inactiveDays && !result.Dirty && !anyDirtyWorktree {
		result.Findings = append(result.Findings, "inactive")
	}
	return result, nil
}

func (s *scanner) upstreamCounts(repo string) (*string, *int, *int) {
	output, err := s.gitOutput(repo, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
	if err != nil {
		return nil, nil, nil
	}
	upstream := strings.TrimSpace(string(output))
	counts, err := s.gitOutput(repo, "rev-list", "--left-right", "--count", upstream+"...HEAD")
	if err != nil {
		return &upstream, nil, nil
	}
	var behind, ahead int
	if _, err := fmt.Sscanf(string(counts), "%d\t%d", &behind, &ahead); err != nil {
		return &upstream, nil, nil
	}
	return &upstream, &ahead, &behind
}

func (s *scanner) projectSignals(path string) ([]string, error) {
	var found []string
	err := filepath.WalkDir(path, func(current string, entry os.DirEntry, walkErr error) error {
		if err := s.ctx.Err(); err != nil {
			return err
		}
		if walkErr != nil {
			return nil
		}
		relative, _ := filepath.Rel(path, current)
		depth := 0
		if relative != "." {
			depth = len(strings.Split(relative, string(filepath.Separator)))
		}
		if entry.IsDir() && current != path {
			if skipDirs[entry.Name()] || depth > 2 {
				return filepath.SkipDir
			}
			return nil
		}
		if entry.IsDir() {
			return nil
		}
		for _, marker := range projectMarkers {
			if entry.Name() == marker {
				found = append(found, filepath.ToSlash(relative))
				if len(found) >= 8 {
					return filepath.SkipAll
				}
			}
		}
		return nil
	})
	if err != nil && s.ctx.Err() != nil {
		return nil, s.ctx.Err()
	}
	sort.Strings(found)
	return found, nil
}

func scan(root string, inactiveDays, workers int) (report, error) {
	s := scanner{
		ctx: context.Background(), root: canonical(root), now: time.Now().UTC(),
		inactiveDays: inactiveDays, workers: workers, gitSlots: make(chan struct{}, workers),
	}
	return s.scan()
}

func (s *scanner) scan() (report, error) {
	roots, err := s.findRepositories()
	if err != nil {
		return report{}, err
	}
	result := report{
		SchemaVersion: 1, Root: s.root, ScannedAt: s.now.Format(time.RFC3339Nano), InactiveAfterDays: s.inactiveDays,
		Repositories: []repository{}, UninitializedCandidates: []candidate{}, Containers: []container{},
		Worktrees: []worktree{}, Findings: []finding{},
	}
	inspected, err := parallelMap(s.ctx, roots, s.workers, func(ctx context.Context, repoPath string) (repository, error) {
		task := *s
		task.ctx = ctx
		return task.inspectRepository(repoPath)
	})
	if err != nil {
		return report{}, err
	}
	for _, repo := range inspected {
		if repo.AbsolutePath != "" {
			result.Repositories = append(result.Repositories, repo)
		}
	}
	worktreeMap := map[string]worktree{}
	for _, repo := range result.Repositories {
		for _, tree := range repo.Worktrees {
			key := canonical(tree.Path)
			if tree.OwnerRepo == "" {
				tree.OwnerRepo = repo.Path
			}
			worktreeMap[key] = tree
		}
	}
	entries, err := os.ReadDir(s.root)
	if err != nil {
		return result, err
	}
	candidateDirs := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		directory := canonical(filepath.Join(s.root, entry.Name()))
		if contains(roots, directory) {
			continue
		}
		var contained []string
		for _, repoPath := range roots {
			if repoPath != directory && inside(repoPath, directory) {
				contained = append(contained, rel(repoPath, s.root))
			}
		}
		if len(contained) > 0 {
			result.Containers = append(result.Containers, container{
				Path: rel(directory, s.root), RepositoryCount: len(contained), Repositories: contained,
			})
			continue
		}
		candidateDirs = append(candidateDirs, directory)
	}
	candidates, err := parallelMap(s.ctx, candidateDirs, s.workers, func(ctx context.Context, directory string) (candidate, error) {
		task := *s
		task.ctx = ctx
		signals, err := task.projectSignals(directory)
		if err != nil {
			return candidate{}, err
		}
		if len(signals) > 0 {
			return candidate{
				Path: rel(directory, s.root), Signals: signals, Finding: "no-git-repository",
			}, nil
		}
		return candidate{}, nil
	})
	if err != nil {
		return report{}, err
	}
	for _, item := range candidates {
		if item.Path != "" {
			result.UninitializedCandidates = append(result.UninitializedCandidates, item)
		}
	}
	for _, repo := range result.Repositories {
		if len(repo.Findings) > 0 {
			result.Findings = append(result.Findings, finding{Path: repo.Path, Reasons: repo.Findings})
		}
	}
	for _, item := range result.UninitializedCandidates {
		result.Findings = append(result.Findings, finding{Path: item.Path, Reasons: []string{item.Finding}})
	}
	for _, tree := range worktreeMap {
		result.Worktrees = append(result.Worktrees, tree)
	}
	sort.Slice(result.Worktrees, func(i, j int) bool {
		return strings.ToLower(result.Worktrees[i].Path) < strings.ToLower(result.Worktrees[j].Path)
	})
	result.WorktreeCount = len(result.Worktrees)
	return result, nil
}

func inside(path, directory string) bool {
	relative, err := filepath.Rel(directory, path)
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func contains(items []string, value string) bool {
	for _, item := range items {
		if item == value {
			return true
		}
	}
	return false
}

func printText(value report) {
	fmt.Printf("Projects root: %s\n", value.Root)
	fmt.Printf("Repositories: %d; uninitialized candidates: %d; containers: %d; worktrees: %d\n",
		len(value.Repositories), len(value.UninitializedCandidates), len(value.Containers), value.WorktreeCount)
	if len(value.Repositories) > 0 {
		fmt.Println("\nREPOSITORY  BRANCH  STATE  ACTIVITY")
		for _, repo := range value.Repositories {
			state := strings.Join(repo.Findings, ",")
			if state == "" {
				state = "ok"
			}
			branch := "detached"
			if repo.Branch != nil {
				branch = *repo.Branch
			} else if !repo.HasCommits {
				branch = "unborn"
			}
			activity := "unknown"
			if repo.ActivityAgeDays != nil {
				activity = fmt.Sprintf("%dd ago", *repo.ActivityAgeDays)
			}
			fmt.Printf("%s  %s  %s  %s\n", repo.Path, branch, state, activity)
		}
	}
	if len(value.Worktrees) > 0 {
		fmt.Println("\nGIT WORKTREES")
		for _, tree := range value.Worktrees {
			label, state := "linked", "clean"
			if tree.Primary {
				label = "primary"
			}
			if tree.Prunable {
				state = "prunable"
			} else if !tree.Available {
				state = "missing"
			} else if tree.Dirty != nil && *tree.Dirty {
				state = "dirty"
			}
			branch := "detached"
			if tree.Branch != "" {
				branch = tree.Branch
			}
			fmt.Printf("%s: %s [%s; %s]\n", label, tree.Path, branch, state)
		}
	}
	if len(value.UninitializedCandidates) > 0 {
		fmt.Println("\nPROJECT CANDIDATES WITHOUT GIT")
		for _, item := range value.UninitializedCandidates {
			fmt.Printf("%s  signals: %s\n", item.Path, strings.Join(item.Signals, ", "))
		}
	}
	if len(value.Containers) > 0 {
		fmt.Println("\nDIRECTORIES CONTAINING NESTED REPOSITORIES")
		for _, item := range value.Containers {
			fmt.Printf("%s  repositories: %d\n", item.Path, item.RepositoryCount)
		}
	}
	if len(value.Findings) > 0 {
		fmt.Printf("\nReview candidates: %d\n", len(value.Findings))
	} else {
		fmt.Println("\nNo review candidates found.")
	}
}

func runScan(args []string) int {
	flags := flag.NewFlagSet("project-scan", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	root := flags.String("root", os.Getenv("NIX_CONFIG_PATH_PROJECTS"), "scan root")
	inactiveDays := flags.Int("inactive-days", 90, "flag repositories without activity for this many days")
	jsonOutput := flags.Bool("json", false, "print structured JSON")
	workers := flags.Int("workers", defaultWorkers(), "maximum concurrent repository and candidate scans")
	exitOnFindings := flags.Bool("exit-code-on-findings", false, "exit 1 when review candidates are found")
	if err := flags.Parse(args); err != nil {
		return 2
	}
	if *root == "" {
		fmt.Fprintln(os.Stderr, "set NIX_CONFIG_PATH_PROJECTS or pass --root")
		return 2
	}
	*root = expandUserPath(*root)
	if *inactiveDays < 1 {
		fmt.Fprintln(os.Stderr, "--inactive-days must be at least 1")
		return 2
	}
	if *workers < 1 || *workers > 64 {
		fmt.Fprintln(os.Stderr, "--workers must be between 1 and 64")
		return 2
	}
	if !isDirectory(*root) {
		fmt.Fprintf(os.Stderr, "projects root is not a directory: %s\n", *root)
		return 2
	}
	value, err := scan(*root, *inactiveDays, *workers)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	if *jsonOutput {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		encoder.SetEscapeHTML(false)
		if err := encoder.Encode(value); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
	} else {
		printText(value)
	}
	if *exitOnFindings && len(value.Findings) > 0 {
		return 1
	}
	return 0
}
