package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
	"unicode"
)

const (
	snapshotNamespace = "refs/heads/snapshots"
	legacyNamespace   = "refs/nix-project-snapshots"
	stagingNamespace  = "refs/nix-project-snapshot-staging"
)

type worktreeTarget struct {
	path  string
	repo  string
	entry worktree
}

type gitResult struct {
	stdout string
	stderr string
}

func gitCommand(env map[string]string, args ...string) (gitResult, error) {
	command := exec.Command("git", args...)
	if env != nil {
		command.Env = os.Environ()
		for key, value := range env {
			command.Env = setEnvironment(command.Env, key, value)
		}
	}
	var stdout, stderr strings.Builder
	command.Stdout = &stdout
	command.Stderr = &stderr
	err := command.Run()
	result := gitResult{stdout: stdout.String(), stderr: stderr.String()}
	if err != nil {
		return result, fmt.Errorf("git %s: %s", strings.Join(args, " "), strings.TrimSpace(result.stderr))
	}
	return result, nil
}

func setEnvironment(env []string, name, value string) []string {
	prefix := name + "="
	for index, item := range env {
		if strings.HasPrefix(item, prefix) {
			env[index] = prefix + value
			return env
		}
	}
	return append(env, prefix+value)
}

func gitAt(directory string, args ...string) (gitResult, error) {
	return gitCommand(nil, append([]string{"-C", directory}, args...)...)
}

func bareGit(gitDir string, env map[string]string, args ...string) (gitResult, error) {
	return gitCommand(env, append([]string{"--git-dir=" + gitDir}, args...)...)
}

func worktreeGit(gitDir, worktree string, env map[string]string, args ...string) (gitResult, error) {
	return gitCommand(env, append([]string{"--git-dir=" + gitDir, "--work-tree=" + worktree}, args...)...)
}

func validateRemoteURL(remote string) error {
	if strings.TrimSpace(remote) == "" {
		return nil
	}
	if isSCPSSHRemote(remote) {
		return nil
	}
	parsed, err := url.Parse(remote)
	if err != nil {
		// Git's common SSH form (user@host:path) is not an RFC URL.
		if isSCPSSHRemote(remote) {
			return nil
		}
		return fmt.Errorf("invalid snapshot remote URL: %w", err)
	}
	if parsed.Scheme == "" {
		if isSCPSSHRemote(remote) {
			return nil
		}
		return errors.New("snapshot remote must use HTTPS or SSH (ssh:// or user@host:path)")
	}
	if parsed.Scheme != "https" && parsed.Scheme != "ssh" {
		return errors.New("snapshot remote must use HTTPS or SSH (ssh:// or user@host:path)")
	}
	if parsed.Host == "" || parsed.Path == "" {
		return errors.New("snapshot remote URL must include a host and repository path")
	}
	if parsed.User != nil {
		_, hasPassword := parsed.User.Password()
		if parsed.Scheme != "ssh" || hasPassword {
			return errors.New("snapshot remote URL must not contain credentials; use SSH agent/config or a Git credential helper")
		}
	}
	if parsed.RawQuery != "" || parsed.Fragment != "" {
		return errors.New("snapshot remote URLs must not contain query strings or fragments; use a Git credential helper")
	}
	return nil
}

func isSCPSSHRemote(remote string) bool {
	if remote == "" || strings.Contains(remote, "://") || strings.ContainsAny(remote, " \t\r\n") {
		return false
	}
	colon := strings.IndexByte(remote, ':')
	if strings.HasPrefix(remote, "[") {
		closeBracket := strings.IndexByte(remote, ']')
		if closeBracket < 0 || closeBracket+1 >= len(remote) || remote[closeBracket+1] != ':' {
			return false
		}
		colon = closeBracket + 1
		if net.ParseIP(remote[1:closeBracket]) == nil {
			return false
		}
	}
	if colon <= 0 || colon == len(remote)-1 {
		return false
	}
	userHost := remote[:colon]
	if strings.Contains(userHost, "/") || strings.Count(userHost, "@") > 1 {
		return false
	}
	if at := strings.LastIndexByte(userHost, '@'); at >= 0 {
		if at == 0 || at == len(userHost)-1 {
			return false
		}
		userHost = userHost[at+1:]
	}
	if strings.HasPrefix(userHost, "[") {
		return strings.HasSuffix(userHost, "]")
	}
	for _, character := range userHost {
		if !(character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z' || character >= '0' && character <= '9' || character == '.' || character == '-' || character == '_') {
			return false
		}
	}
	return userHost != ""
}

func remoteSnapshotRefs(remote string) (map[string]string, error) {
	if err := validateRemoteURL(remote); err != nil {
		return nil, err
	}
	return queryRemoteSnapshotRefs(remote)
}

func queryRemoteSnapshotRefs(remote string) (map[string]string, error) {
	result, err := gitCommand(map[string]string{"GIT_TERMINAL_PROMPT": "0"}, "ls-remote", "--refs", remote, snapshotNamespace)
	if err != nil {
		return nil, err
	}
	refs := map[string]string{}
	for _, line := range strings.Split(strings.TrimSpace(result.stdout), "\n") {
		if line == "" {
			continue
		}
		object, ref, ok := strings.Cut(line, "\t")
		if ok && ref == snapshotNamespace {
			refs[ref] = object
		}
	}
	return refs, nil
}

// syncSnapshotRefs updates only the dedicated project snapshots branch. Each
// project has its own remote bare repository; a lease prevents overwriting a
// concurrent update made through another client.
func syncSnapshotRefs(gitDir, remote string) (synced, pending int, err error) {
	if remote == "" {
		return 0, 0, nil
	}
	if err := validateRemoteURL(remote); err != nil {
		return 0, 0, err
	}
	return syncSnapshotRefsValidated(gitDir, remote)
}

func syncSnapshotRefsValidated(gitDir, remote string) (synced, pending int, err error) {
	local, err := bareGit(gitDir, nil, "rev-parse", "--verify", snapshotNamespace)
	if err != nil {
		return 0, 0, nil
	}
	localObject := strings.TrimSpace(local.stdout)
	remoteRefs, err := queryRemoteSnapshotRefs(remote)
	if err != nil {
		return 0, 1, err
	}
	if remoteRefs[snapshotNamespace] == localObject {
		return 1, 0, nil
	}
	lease := "--force-with-lease=" + snapshotNamespace + ":"
	if remoteObject := remoteRefs[snapshotNamespace]; remoteObject != "" {
		lease += remoteObject
	}
	_, err = gitCommand(map[string]string{"GIT_TERMINAL_PROMPT": "0"}, "--git-dir="+gitDir, "push", "--no-follow-tags", lease, remote, snapshotNamespace+":"+snapshotNamespace)
	if err != nil {
		return 0, 1, err
	}
	return 1, 0, nil
}

func commonGitDir(repo string) (string, error) {
	result, err := gitAt(repo, "rev-parse", "--git-common-dir")
	if err != nil {
		return "", err
	}
	path := strings.TrimSpace(result.stdout)
	if !filepath.IsAbs(path) {
		path = filepath.Join(repo, path)
	}
	return resolvePath(path)
}

func resolvePath(path string) (string, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	var tail []string
	for current := absolute; ; current = filepath.Dir(current) {
		resolved, resolveErr := filepath.EvalSymlinks(current)
		if resolveErr == nil {
			for index := len(tail) - 1; index >= 0; index-- {
				resolved = filepath.Join(resolved, tail[index])
			}
			return filepath.Clean(resolved), nil
		}
		parent := filepath.Dir(current)
		if parent == current {
			return "", resolveErr
		}
		tail = append(tail, filepath.Base(current))
	}
}

func safeInside(path, parent string) (bool, error) {
	resolvedPath, err := resolvePath(path)
	if err != nil {
		return false, err
	}
	resolvedParent, err := resolvePath(parent)
	if err != nil {
		return false, err
	}
	relative, err := filepath.Rel(resolvedParent, resolvedPath)
	if err != nil {
		return false, err
	}
	return relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator)), nil
}

func stableID(value string) string {
	digest := sha256.Sum256([]byte(value))
	return hex.EncodeToString(digest[:])[:20]
}

func projectIDForPath(path string, overrides map[string]string) (string, error) {
	normalized, err := resolvePath(path)
	if err != nil {
		return "", err
	}
	if override := overrides[normalized]; override != "" {
		if !validProjectID(override) {
			return "", fmt.Errorf("invalid project ID override %q for %s", override, normalized)
		}
		return override, nil
	}
	return stableID(normalized), nil
}

func validProjectID(value string) bool {
	if value == "" || value == "." || value == ".." {
		return false
	}
	for _, character := range value {
		if !(character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z' || character >= '0' && character <= '9' || character == '-' || character == '_' || character == '.') {
			return false
		}
	}
	return true
}

func remoteRepositoryURL(sshHost, root, hostID, projectID string) (string, string, error) {
	if sshHost == "" || root == "" || hostID == "" || projectID == "" {
		return "", "", errors.New("remote snapshot target requires SSH alias, root, host ID, and project ID")
	}
	if !filepath.IsAbs(root) || filepath.Clean(root) != root || root == string(filepath.Separator) || !validProjectID(hostID) || !validProjectID(projectID) || strings.ContainsAny(sshHost+root, "\r\n\x00") || !validSSHHostAlias(sshHost) {
		return "", "", errors.New("remote snapshot root must be absolute and target fields must be single-line values")
	}
	remotePath := filepath.ToSlash(filepath.Join(root, hostID, projectID+".git"))
	remoteURL := (&url.URL{Scheme: "ssh", Host: sshHost, Path: remotePath}).String()
	return remoteURL, remotePath, nil
}

func validSSHHostAlias(value string) bool {
	if value == "" {
		return false
	}
	for _, character := range value {
		if !(character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z' || character >= '0' && character <= '9' || character == '.' || character == '-' || character == '_') {
			return false
		}
	}
	return true
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func provisionSSHRepository(sshHost, remotePath string) error {
	parent := filepath.ToSlash(filepath.Dir(remotePath))
	command := "mkdir -p -- " + shellQuote(parent) + " && if [ ! -d " + shellQuote(remotePath) + " ]; then git init --bare --quiet " + shellQuote(remotePath) + "; fi && git --git-dir=" + shellQuote(remotePath) + " rev-parse --is-bare-repository"
	process := exec.Command("ssh", "-o", "BatchMode=yes", sshHost, command)
	var stdout, stderr strings.Builder
	process.Stdout = &stdout
	process.Stderr = &stderr
	err := process.Run()
	if err != nil {
		return fmt.Errorf("could not provision remote snapshot repository: %s", strings.TrimSpace(stderr.String()))
	}
	if strings.TrimSpace(stdout.String()) != "true" {
		return fmt.Errorf("remote snapshot path is not a bare Git repository: %s", remotePath)
	}
	return nil
}

func backupStore(root, repo, commonDir string) (string, error) {
	label := strings.Map(func(character rune) rune {
		if unicode.IsLetter(character) || unicode.IsDigit(character) {
			return unicode.ToLower(character)
		}
		return '-'
	}, filepath.Base(repo))
	label = strings.Trim(strings.Join(strings.FieldsFunc(label, func(character rune) bool { return character == '-' }), "-"), "-")
	if runes := []rune(label); len(runes) > 40 {
		label = string(runes[:40])
	}
	if label == "" {
		label = "repository"
	}
	store := filepath.Join(root, label+"-"+stableID(commonDir)+".git")
	if _, err := os.Stat(store); errors.Is(err, os.ErrNotExist) {
		if err := os.MkdirAll(root, 0o700); err != nil {
			return "", err
		}
		if _, err := gitCommand(nil, "init", "--bare", "--quiet", store); err != nil {
			return "", err
		}
	} else if err != nil {
		return "", err
	}
	if err := os.Chmod(store, 0o700); err != nil {
		return "", err
	}
	return store, nil
}

func latestSnapshot(gitDir, _ string) (string, string, error) {
	result, err := bareGit(gitDir, nil, "rev-parse", "--verify", snapshotNamespace)
	if err != nil {
		return "", "", nil
	}
	return snapshotNamespace, strings.TrimSpace(result.stdout), nil
}

func snapshotMatches(gitDir, latestCommit, tree, head string) (bool, error) {
	treeResult, treeErr := bareGit(gitDir, nil, "rev-parse", "--verify", latestCommit+"^{tree}")
	messageResult, messageErr := bareGit(gitDir, nil, "show", "-s", "--format=%B", latestCommit)
	if treeErr != nil || messageErr != nil {
		return false, nil
	}
	for _, line := range strings.Split(messageResult.stdout, "\n") {
		if strings.HasPrefix(line, "Source-HEAD: ") {
			headValue := head
			if headValue == "" {
				headValue = "none"
			}
			return strings.TrimSpace(treeResult.stdout) == tree && strings.TrimPrefix(line, "Source-HEAD: ") == headValue, nil
		}
	}
	return false, nil
}

func optionalHead(head string) []string {
	if head == "" {
		return nil
	}
	return []string{head}
}

func equalStrings(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if left[index] != right[index] {
			return false
		}
	}
	return true
}

func needsSnapshot(worktreePath string) (bool, string, string, string, error) {
	headResult, headErr := gitAt(worktreePath, "rev-parse", "--verify", "HEAD")
	head := ""
	if headErr == nil {
		head = strings.TrimSpace(headResult.stdout)
	}
	statusResult, err := gitAt(worktreePath, "status", "--porcelain=v1", "--untracked-files=normal")
	if err != nil {
		return false, "", "", "", fmt.Errorf("could not inspect working tree: %s", worktreePath)
	}
	dirty := strings.TrimSpace(statusResult.stdout) != ""

	upstreamResult, upstreamErr := gitAt(worktreePath, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
	if upstreamErr == nil && head != "" {
		upstream := strings.TrimSpace(upstreamResult.stdout)
		counts, countErr := gitAt(worktreePath, "rev-list", "--left-right", "--count", upstream+"...HEAD")
		ahead := 0
		if countErr == nil {
			var behind int
			if _, scanErr := fmt.Sscanf(counts.stdout, "%d\t%d", &behind, &ahead); scanErr != nil {
				ahead = 0
			}
		}
		if dirty {
			return true, "dirty", head, upstream, nil
		}
		return ahead > 0, "unpushed", head, upstream, nil
	}
	if dirty {
		return true, "dirty", head, "", nil
	}
	if head != "" {
		return true, "no-upstream", head, "", nil
	}
	return false, "empty", "", "", nil
}

func sourceBranch(worktreePath string) string {
	result, err := gitAt(worktreePath, "symbolic-ref", "--quiet", "--short", "HEAD")
	if err != nil {
		return "detached"
	}
	return strings.TrimSpace(result.stdout)
}

func makeTree(gitDir, worktreePath, indexPath, head string) (string, error) {
	env := map[string]string{"GIT_INDEX_FILE": indexPath}
	readTreeArgs := []string{"read-tree", "--empty"}
	if head != "" {
		readTreeArgs = []string{"read-tree", head}
	}
	if _, err := bareGit(gitDir, env, readTreeArgs...); err != nil {
		return "", err
	}
	if _, err := worktreeGit(gitDir, worktreePath, env, "add", "-A", "--", "."); err != nil {
		return "", err
	}
	result, err := bareGit(gitDir, env, "write-tree")
	return strings.TrimSpace(result.stdout), err
}

func createSnapshotCommit(gitDir, indexPath, tree, head, parent, branch, worktreeID, projectID, reason string, stamp time.Time) (string, error) {
	env := map[string]string{
		"GIT_INDEX_FILE":      indexPath,
		"GIT_AUTHOR_NAME":     "Project Snapshot",
		"GIT_AUTHOR_EMAIL":    "project-snapshot@localhost",
		"GIT_COMMITTER_NAME":  "Project Snapshot",
		"GIT_COMMITTER_EMAIL": "project-snapshot@localhost",
		"GIT_AUTHOR_DATE":     fmt.Sprintf("@%d +0000", stamp.Unix()),
		"GIT_COMMITTER_DATE":  fmt.Sprintf("@%d +0000", stamp.Unix()),
	}
	args := []string{"commit-tree", tree}
	if parent != "" {
		args = append(args, "-p", parent)
	}
	if branch == "" {
		branch = "detached"
	}
	if head == "" {
		head = "none"
	}
	message := strings.Join([]string{
		"Project worktree snapshot",
		"",
		"Snapshot-Time: " + stamp.Format(time.RFC3339Nano),
		"Project-ID: " + projectID,
		"Worktree-ID: " + worktreeID,
		"Source-Branch: " + branch,
		"Source-HEAD: " + head,
		"Snapshot-Reason: " + reason,
	}, "\n")
	args = append(args, "-m", message)
	result, err := bareGit(gitDir, env, args...)
	return strings.TrimSpace(result.stdout), err
}

func pruneOldSnapshots(gitDir string, retentionDays int, now time.Time) (int, error) {
	head, err := bareGit(gitDir, nil, "rev-parse", "--verify", snapshotNamespace)
	if err != nil {
		return 0, nil
	}
	cutoff := now.AddDate(0, 0, -retentionDays)
	oldTip := strings.TrimSpace(head.stdout)
	commits, err := bareGit(gitDir, nil, "rev-list", "--reverse", oldTip)
	if err != nil {
		return 0, err
	}
	type retainedSnapshot struct {
		tree, message string
		stamp         time.Time
	}
	var retained []retainedSnapshot
	removed := 0
	for _, commit := range nonEmptyLines(commits.stdout) {
		details, err := bareGit(gitDir, nil, "show", "-s", "--format=%T%n%cI%n%B", commit)
		if err != nil {
			return removed, err
		}
		lines := strings.SplitN(details.stdout, "\n", 3)
		if len(lines) != 3 {
			return removed, fmt.Errorf("invalid snapshot commit %s", commit)
		}
		stamp, err := time.Parse(time.RFC3339, strings.TrimSpace(lines[1]))
		if err != nil {
			return removed, err
		}
		if stamp.Before(cutoff) {
			removed++
			continue
		}
		retained = append(retained, retainedSnapshot{tree: strings.TrimSpace(lines[0]), message: strings.TrimRight(lines[2], "\n"), stamp: stamp})
	}
	if removed > 0 {
		newTip := ""
		for _, snapshot := range retained {
			env := map[string]string{
				"GIT_AUTHOR_NAME": "Project Snapshot", "GIT_AUTHOR_EMAIL": "project-snapshot@localhost",
				"GIT_COMMITTER_NAME": "Project Snapshot", "GIT_COMMITTER_EMAIL": "project-snapshot@localhost",
				"GIT_AUTHOR_DATE": snapshot.stamp.Format(time.RFC3339), "GIT_COMMITTER_DATE": snapshot.stamp.Format(time.RFC3339),
			}
			args := []string{"commit-tree", snapshot.tree}
			if newTip != "" {
				args = append(args, "-p", newTip)
			}
			args = append(args, "-m", snapshot.message)
			created, err := bareGit(gitDir, env, args...)
			if err != nil {
				return removed, err
			}
			newTip = strings.TrimSpace(created.stdout)
		}
		if newTip == "" {
			_, err = bareGit(gitDir, nil, "update-ref", "-d", snapshotNamespace, oldTip)
		} else {
			_, err = bareGit(gitDir, nil, "update-ref", snapshotNamespace, newTip, oldTip)
		}
		if err != nil {
			return removed, err
		}
		if _, err := bareGit(gitDir, nil, "gc", "--quiet", "--prune=2.weeks.ago"); err != nil {
			return removed, err
		}
	}
	return removed, nil
}

func snapshotOne(worktreePath, repo, backupRoot, projectsRoot string, retentionDays int, now time.Time) (string, string, error) {
	commonDir, err := commonGitDir(repo)
	if err != nil {
		return "", "", err
	}
	return snapshotOneWithID(worktreePath, repo, backupRoot, projectsRoot, retentionDays, now, stableID(commonDir))
}

func snapshotOneWithID(worktreePath, repo, backupRoot, projectsRoot string, retentionDays int, now time.Time, projectID string) (string, string, error) {
	worktreePath, err := resolvePath(worktreePath)
	if err != nil {
		return "", "", err
	}
	info, err := os.Stat(worktreePath)
	if err != nil || !info.IsDir() {
		return "skipped", "missing worktree: " + worktreePath, nil
	}
	inside, err := safeInside(backupRoot, projectsRoot)
	if err != nil {
		return "", "", err
	}
	insideWorktree, err := safeInside(worktreePath, backupRoot)
	if err != nil {
		return "", "", err
	}
	if inside || insideWorktree {
		return "", "", errors.New("snapshot storage must stay outside the projects tree and source worktrees")
	}

	needed, reason, head, _, err := needsSnapshot(worktreePath)
	if err != nil {
		return "", "", err
	}
	commonDir, err := commonGitDir(repo)
	if err != nil {
		return "", "", err
	}
	store, err := backupStore(backupRoot, repo, commonDir)
	if err != nil {
		return "", "", err
	}
	worktreeID := stableID(worktreePath)
	_, latestCommit, err := latestSnapshot(store, worktreeID)
	if err != nil {
		return "", "", err
	}
	if !needed {
		return "skipped", "clean and synchronized: " + worktreePath, nil
	}

	stamp := now.UTC()
	stageBytes := make([]byte, 12)
	if _, err := rand.Read(stageBytes); err != nil {
		return "", "", err
	}
	stagingRef := stagingNamespace + "/" + hex.EncodeToString(stageBytes)
	temporaryRoot, err := os.MkdirTemp(backupRoot, "project-snapshot-")
	if err != nil {
		return "", "", err
	}
	defer os.RemoveAll(temporaryRoot)
	temporaryGitDir := filepath.Join(temporaryRoot, "snapshot.git")
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", temporaryGitDir); err != nil {
		return "", "", err
	}
	alternates := filepath.Join(temporaryGitDir, "objects", "info", "alternates")
	if err := os.WriteFile(alternates, []byte(filepath.Join(commonDir, "objects")+"\n"+filepath.Join(store, "objects")+"\n"), 0o600); err != nil {
		return "", "", err
	}
	sourceExcludes := filepath.Join(commonDir, "info", "exclude")
	if info, err := os.Stat(sourceExcludes); err == nil && info.Mode().IsRegular() {
		if err := copyFile(sourceExcludes, filepath.Join(temporaryGitDir, "info", "exclude")); err != nil {
			return "", "", err
		}
	}
	if excludes, err := gitAt(worktreePath, "config", "--path", "--get", "core.excludesFile"); err == nil {
		if _, err := bareGit(temporaryGitDir, nil, "config", "core.excludesFile", strings.TrimSpace(excludes.stdout)); err != nil {
			return "", "", err
		}
	}
	indexPath := filepath.Join(temporaryRoot, "index")
	tree, err := makeTree(temporaryGitDir, worktreePath, indexPath, head)
	if err != nil {
		return "", "", err
	}
	if latestCommit != "" {
		matches, err := snapshotMatches(store, latestCommit, tree, head)
		if err != nil {
			return "", "", err
		}
		if matches {
			return "unchanged", "snapshot already current: " + worktreePath, nil
		}
	}
	branch := sourceBranch(worktreePath)
	snapshotCommit, err := createSnapshotCommit(temporaryGitDir, indexPath, tree, head, latestCommit, branch, worktreeID, projectID, reason, stamp)
	if err != nil {
		return "", "", err
	}
	if _, err := bareGit(temporaryGitDir, nil, "update-ref", stagingRef, snapshotCommit); err != nil {
		return "", "", err
	}
	localStagingRef := stagingRef + "/" + stableID(worktreePath)
	if _, err := bareGit(store, nil, "fetch", "--quiet", "--no-tags", temporaryGitDir, stagingRef+":"+localStagingRef); err != nil {
		return "", "", err
	}
	if latestCommit == "" {
		_, err = bareGit(store, nil, "update-ref", snapshotNamespace, snapshotCommit)
	} else {
		_, err = bareGit(store, nil, "update-ref", snapshotNamespace, snapshotCommit, latestCommit)
	}
	if err != nil {
		return "", "", err
	}
	_, _ = bareGit(store, nil, "update-ref", "-d", localStagingRef)
	return "saved", fmt.Sprintf("%s (%s)", worktreePath, reason), nil
}

func copyFile(source, destination string) error {
	contents, err := os.ReadFile(source)
	if err != nil {
		return err
	}
	return os.WriteFile(destination, contents, 0o600)
}

func allWorktrees(root string, workers int) ([]worktreeTarget, error) {
	s := &scanner{ctx: context.Background(), root: root, workers: workers, gitSlots: make(chan struct{}, workers)}
	roots, err := s.findRepositories()
	if err != nil {
		return nil, err
	}
	commonDirs := map[string]bool{}
	seenTrees := map[string]bool{}
	var targets []worktreeTarget
	for _, repo := range roots {
		commonDir, err := commonGitDir(repo)
		if err != nil || commonDirs[commonDir] {
			continue
		}
		commonDirs[commonDir] = true
		entries, err := s.parseWorktrees(repo)
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			key := canonical(entry.Path)
			if seenTrees[key] {
				continue
			}
			seenTrees[key] = true
			targets = append(targets, worktreeTarget{path: entry.Path, repo: repo, entry: entry})
		}
	}
	return targets, nil
}

func listLegacySnapshots(store string) bool {
	legacy, err := bareGit(store, nil, "for-each-ref", "--sort=-refname", "--format=%(refname) %(objectname)", legacyNamespace)
	if err != nil { return false }
	found := false
	for _, line := range nonEmptyLines(legacy.stdout) {
		ref, commit, ok := strings.Cut(line, " ")
		if !ok { continue }
		details, err := bareGit(store, nil, "show", "-s", "--format=%cI%n%s", commit)
		if err == nil {
			fmt.Printf("%s\t%s\tremote=legacy-local\t%s\n", store, ref, strings.ReplaceAll(strings.TrimSpace(details.stdout), "\n", " — "))
			found = true
		}
	}
	return found
}

func listSnapshots(backupRoot, remote string) error {
	found := false
	localRefs := map[string]string{}
	remoteRefs := map[string]string{}
	remoteStatus := "disabled"
	if remote != "" {
		var err error
		remoteRefs, err = remoteSnapshotRefs(remote)
		if err != nil {
			remoteStatus = "unavailable"
			fmt.Fprintf(os.Stderr, "Remote snapshot status unavailable: %v\n", err)
		} else {
			remoteStatus = "connected"
		}
	}
	stores, err := filepath.Glob(filepath.Join(backupRoot, "*.git"))
	if err != nil {
		return err
	}
	sort.Strings(stores)
	for _, store := range stores {
		tip, err := bareGit(store, nil, "rev-parse", "--verify", snapshotNamespace)
		if err != nil {
			found = listLegacySnapshots(store) || found
			continue
		}
		commits, err := bareGit(store, nil, "rev-list", "--reverse", strings.TrimSpace(tip.stdout))
		if err != nil {
			continue
		}
		localRefs[snapshotNamespace] = strings.TrimSpace(tip.stdout)
		for _, commit := range nonEmptyLines(commits.stdout) {
			details, err := bareGit(store, nil, "show", "-s", "--format=%cI%n%s", commit)
			if err != nil {
				continue
			}
			found = true
			state := remoteStatus
			if remote != "" && remoteStatus == "connected" {
				if remoteRefs[snapshotNamespace] == strings.TrimSpace(tip.stdout) {
					state = "synced"
				} else {
					state = "pending"
				}
			}
			fmt.Printf("%s\t%s\tremote=%s\t%s\n", store, commit, state, strings.ReplaceAll(strings.TrimSpace(details.stdout), "\n", " — "))
		}
		found = listLegacySnapshots(store) || found
	}
	if remote != "" && remoteStatus == "connected" {
		remoteOnly := make([]string, 0, len(remoteRefs))
		for ref := range remoteRefs {
			remoteOnly = append(remoteOnly, ref)
		}
		sort.Strings(remoteOnly)
		for _, ref := range remoteOnly {
			if _, exists := localRefs[ref]; exists {
				continue
			}
			found = true
			fmt.Printf("-\t%s\tremote=remote-only\t%s\n", ref, remoteRefs[ref])
		}
	}
	if !found {
		fmt.Println("No project snapshots found.")
	}
	return nil
}

func checkSnapshots(output io.Writer, snapshotRoot, remote string) error {
	return checkSnapshotsUsing(output, snapshotRoot, remote, remoteSnapshotRefs)
}

func checkSnapshotsUsing(output io.Writer, snapshotRoot, remote string, queryRemote func(string) (map[string]string, error)) error {
	stores, err := filepath.Glob(filepath.Join(snapshotRoot, "*.git"))
	if err != nil {
		return err
	}
	sort.Strings(stores)
	localRefs := map[string]string{}
	var failures []string
	for _, store := range stores {
		bare, bareErr := bareGit(store, nil, "rev-parse", "--is-bare-repository")
		if bareErr != nil || strings.TrimSpace(bare.stdout) != "true" {
			failures = append(failures, fmt.Sprintf("invalid bare repository: %s", store))
			fmt.Fprintf(output, "ERROR %s invalid-bare-repository\n", store)
			continue
		}
		fsck, fsckErr := bareGit(store, nil, "fsck", "--connectivity-only", "--no-reflogs", "--no-progress")
		if fsckErr != nil {
			failures = append(failures, fmt.Sprintf("git fsck failed for %s: %s", store, strings.TrimSpace(fsck.stderr)))
			fmt.Fprintf(output, "ERROR %s object-connectivity\n", store)
			continue
		}
		tip, refsErr := bareGit(store, nil, "rev-parse", "--verify", snapshotNamespace)
		if refsErr != nil {
			continue
		}
		if _, typeErr := bareGit(store, nil, "cat-file", "-e", strings.TrimSpace(tip.stdout)+"^{commit}"); typeErr != nil {
			failures = append(failures, fmt.Sprintf("snapshot branch does not point to a commit in %s", store))
			continue
		}
		commits, err := bareGit(store, nil, "rev-list", snapshotNamespace)
		if err != nil {
			failures = append(failures, err.Error())
			continue
		}
		count := 0
		for _, object := range nonEmptyLines(commits.stdout) {
			kind, typeErr := bareGit(store, nil, "cat-file", "-t", object)
			if typeErr != nil || strings.TrimSpace(kind.stdout) != "commit" {
				failures = append(failures, fmt.Sprintf("snapshot timeline contains a non-commit: %s", object))
				fmt.Fprintf(output, "ERROR %s invalid-commit\n", object)
				continue
			}
			localRefs[snapshotNamespace] = strings.TrimSpace(tip.stdout)
			count++
		}
		fmt.Fprintf(output, "OK %s refs=%d object-connectivity=verified\n", store, count)
	}
	if len(stores) == 0 {
		fmt.Fprintln(output, "No local snapshot stores found.")
	}
	if remote == "" {
		fmt.Fprintln(output, "Remote check disabled.")
	} else {
		remoteRefs, remoteErr := queryRemote(remote)
		if remoteErr != nil {
			failures = append(failures, "could not inspect snapshot remote: "+remoteErr.Error())
			fmt.Fprintf(output, "ERROR remote unavailable: %v\n", remoteErr)
		} else {
			refs := make([]string, 0, len(localRefs)+len(remoteRefs))
			seen := map[string]bool{}
			for ref := range localRefs {
				refs = append(refs, ref)
				seen[ref] = true
			}
			for ref := range remoteRefs {
				if !seen[ref] {
					refs = append(refs, ref)
				}
			}
			sort.Strings(refs)
			for _, ref := range refs {
				local, hasLocal := localRefs[ref]
				remoteObject, hasRemote := remoteRefs[ref]
				switch {
				case hasLocal && hasRemote && local == remoteObject:
					fmt.Fprintf(output, "OK %s remote=matches\n", ref)
				case hasLocal && hasRemote:
					failures = append(failures, fmt.Sprintf("local and remote snapshot refs differ: %s", ref))
					fmt.Fprintf(output, "ERROR %s remote=mismatch\n", ref)
				case hasLocal:
					failures = append(failures, fmt.Sprintf("snapshot ref is not present on remote: %s", ref))
					fmt.Fprintf(output, "ERROR %s remote=missing\n", ref)
				default:
					fmt.Fprintf(output, "INFO %s local=missing remote=present\n", ref)
				}
			}
			fmt.Fprintln(output, "Remote check verifies ref parity; it does not download remote objects.")
		}
	}
	if len(failures) > 0 {
		return errors.New(strings.Join(failures, "; "))
	}
	return nil
}

func snapshotCommit(store, ref string) (string, error) {
	if strings.HasPrefix(ref, legacyNamespace+"/") {
		if _, err := bareGit(store, nil, "check-ref-format", ref); err != nil {
			return "", fmt.Errorf("invalid legacy snapshot ref: %s", ref)
		}
		commit, err := bareGit(store, nil, "rev-parse", "--verify", ref+"^{commit}")
		if err != nil {
			return "", fmt.Errorf("legacy snapshot ref does not resolve to a commit: %s", ref)
		}
		return strings.TrimSpace(commit.stdout), nil
	}
	if ref == snapshotNamespace {
		ref = snapshotNamespace
	}
	commit, err := bareGit(store, nil, "rev-parse", "--verify", ref+"^{commit}")
	if err != nil {
		return "", fmt.Errorf("snapshot does not resolve to a commit: %s", ref)
	}
	commitID := strings.TrimSpace(commit.stdout)
	if commitID != strings.TrimSpace(ref) {
		if _, err := bareGit(store, nil, "merge-base", "--is-ancestor", commitID, snapshotNamespace); err != nil {
			return "", fmt.Errorf("snapshot %s is not on the retained timeline", ref)
		}
	}
	return commitID, nil
}

func verifyRestoredSnapshot(destination, expectedCommit string) error {
	head, err := gitAt(destination, "rev-parse", "--verify", "HEAD")
	if err != nil || strings.TrimSpace(head.stdout) != expectedCommit {
		return fmt.Errorf("restored HEAD does not match snapshot commit %s", expectedCommit)
	}
	status, err := gitAt(destination, "status", "--porcelain=v1", "--untracked-files=all")
	if err != nil {
		return fmt.Errorf("could not inspect restored worktree: %w", err)
	}
	if strings.TrimSpace(status.stdout) != "" {
		return fmt.Errorf("restored worktree is not clean: %s", strings.TrimSpace(status.stdout))
	}
	return nil
}

func restoreSnapshot(store, ref, destination string) error {
	var err error
	if info, statErr := os.Lstat(destination); statErr == nil && info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("restore destination must not be a symlink: %s", destination)
	} else if statErr != nil && !errors.Is(statErr, os.ErrNotExist) {
		return statErr
	}
	store, err = resolvePath(store)
	if err != nil {
		return err
	}
	destination, err = resolvePath(destination)
	if err != nil {
		return err
	}
	info, err := os.Stat(store)
	if err != nil || !info.IsDir() {
		return fmt.Errorf("snapshot store is not a bare Git repository: %s", store)
	}
	bare, err := bareGit(store, nil, "rev-parse", "--is-bare-repository")
	if err != nil || strings.TrimSpace(bare.stdout) != "true" {
		return fmt.Errorf("snapshot store is not a bare Git repository: %s", store)
	}
	expectedCommit, err := snapshotCommit(store, ref)
	if err != nil {
		return err
	}
	insideStore, err := safeInside(destination, store)
	if err != nil || insideStore {
		return errors.New("restore destination must be outside the snapshot store")
	}
	if entries, err := os.ReadDir(destination); err == nil && len(entries) > 0 {
		return fmt.Errorf("restore destination is not empty: %s", destination)
	} else if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
		return err
	}
	if _, err := bareGit(store, nil, "worktree", "add", "--detach", destination, ref); err != nil {
		return fmt.Errorf("could not restore %s: %w", ref, err)
	}
	if err := verifyRestoredSnapshot(destination, expectedCommit); err != nil {
		_, cleanupErr := bareGit(store, nil, "worktree", "remove", "--force", destination)
		if cleanupErr != nil {
			return fmt.Errorf("restore verification failed: %v; cleanup failed: %w", err, cleanupErr)
		}
		return fmt.Errorf("restore verification failed: %w", err)
	}
	fmt.Printf("Restored %s to %s\n", ref, destination)
	return nil
}

func restoreRemoteSnapshot(snapshotRoot, remote, ref, destination string) error {
	if err := validateRemoteURL(remote); err != nil {
		return err
	}
	return restoreRemoteSnapshotFrom(snapshotRoot, remote, ref, destination)
}

func restoreRemoteSnapshotFrom(snapshotRoot, remote, ref, destination string) error {
	oldUmask := syscall.Umask(0o077)
	defer syscall.Umask(oldUmask)

	if ref == "" {
		return errors.New("remote restore requires a snapshot commit or the snapshots branch")
	}
	if err := os.MkdirAll(snapshotRoot, 0o700); err != nil {
		return err
	}
	if err := securePrivateDir(snapshotRoot); err != nil {
		return fmt.Errorf("could not secure snapshot root: %w", err)
	}
	cache := filepath.Join(snapshotRoot, "remote-cache.git")
	if _, err := os.Stat(cache); errors.Is(err, os.ErrNotExist) {
		if _, err := gitCommand(nil, "init", "--bare", "--quiet", cache); err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	if err := securePrivateGitTree(cache); err != nil {
		return fmt.Errorf("could not secure remote snapshot cache: %w", err)
	}
	if _, err := gitCommand(map[string]string{"GIT_TERMINAL_PROMPT": "0"}, "--git-dir="+cache, "fetch", "--force", "--no-tags", remote, snapshotNamespace+":"+snapshotNamespace); err != nil {
		return fmt.Errorf("could not fetch the remote snapshots timeline: %w", err)
	}
	if err := securePrivateGitTree(cache); err != nil {
		return fmt.Errorf("could not secure fetched snapshot cache: %w", err)
	}
	if err := restoreSnapshot(cache, ref, destination); err != nil {
		return err
	}
	if err := securePrivateGitTree(cache); err != nil {
		return fmt.Errorf("could not secure restored snapshot cache: %w", err)
	}
	return nil
}

func projectIDFromStore(store string) string {
	branch, err := bareGit(store, nil, "rev-parse", "--verify", snapshotNamespace)
	if err == nil {
		metadata, metadataErr := bareGit(store, nil, "show", "-s", "--format=%(trailers:key=Project-ID,valueonly)", strings.TrimSpace(branch.stdout))
		if metadataErr == nil && strings.TrimSpace(metadata.stdout) != "" {
			return strings.TrimSpace(metadata.stdout)
		}
	}
	return strings.TrimSuffix(filepath.Base(store), ".git")
}

func remoteForStore(store, sshHost, root, hostID string) (string, string, error) {
	return remoteRepositoryURL(sshHost, root, hostID, projectIDFromStore(store))
}

func checkSnapshotsWithTarget(output io.Writer, snapshotRoot, sshHost, root, hostID string) error {
	if err := checkSnapshotsUsing(output, snapshotRoot, "", queryRemoteSnapshotRefs); err != nil {
		return err
	}
	stores, err := filepath.Glob(filepath.Join(snapshotRoot, "*.git"))
	if err != nil {
		return err
	}
	var failures []string
	for _, store := range stores {
		remote, _, err := remoteForStore(store, sshHost, root, hostID)
		if err != nil {
			failures = append(failures, err.Error())
			continue
		}
		local, localErr := bareGit(store, nil, "rev-parse", "--verify", snapshotNamespace)
		if localErr != nil {
			continue
		}
		remoteRefs, remoteErr := queryRemoteSnapshotRefs(remote)
		if remoteErr != nil {
			failures = append(failures, "remote unavailable for "+projectIDFromStore(store)+": "+remoteErr.Error())
			continue
		}
		if remoteRefs[snapshotNamespace] != strings.TrimSpace(local.stdout) {
			failures = append(failures, "remote snapshot timeline differs for "+projectIDFromStore(store))
			fmt.Fprintf(output, "ERROR %s remote=mismatch\n", store)
		} else {
			fmt.Fprintf(output, "OK %s remote=matches\n", store)
		}
	}
	if len(failures) > 0 {
		return errors.New(strings.Join(failures, "; "))
	}
	return nil
}

func listSnapshotsWithTarget(snapshotRoot, sshHost, root, hostID string) error {
	stores, err := filepath.Glob(filepath.Join(snapshotRoot, "*.git"))
	if err != nil {
		return err
	}
	sort.Strings(stores)
	found := false
	for _, store := range stores {
		tip, err := bareGit(store, nil, "rev-parse", "--verify", snapshotNamespace)
		if err != nil {
			continue
		}
		remote, _, err := remoteForStore(store, sshHost, root, hostID)
		if err != nil {
			return err
		}
		remoteRefs, remoteErr := queryRemoteSnapshotRefs(remote)
		state := "unavailable"
		if remoteErr == nil {
			if remoteRefs[snapshotNamespace] == strings.TrimSpace(tip.stdout) {
				state = "synced"
			} else {
				state = "pending"
			}
		}
		commits, err := bareGit(store, nil, "rev-list", "--reverse", snapshotNamespace)
		if err != nil {
			return err
		}
		for _, commit := range nonEmptyLines(commits.stdout) {
			details, err := bareGit(store, nil, "show", "-s", "--format=%cI%n%s", commit)
			if err != nil {
				continue
			}
			fmt.Printf("%s\t%s\tremote=%s\t%s\n", store, commit, state, strings.ReplaceAll(strings.TrimSpace(details.stdout), "\n", " — "))
			found = true
		}
	}
	if !found {
		fmt.Println("No project snapshots found.")
	}
	return nil
}

func decodeProjectOverrides(value string) (map[string]string, error) {
	if strings.TrimSpace(value) == "" {
		return map[string]string{}, nil
	}
	var raw map[string]string
	if err := json.Unmarshal([]byte(value), &raw); err != nil {
		return nil, fmt.Errorf("invalid project ID override map: %w", err)
	}
	result := make(map[string]string, len(raw))
	for path, id := range raw {
		normalized, err := resolvePath(expandUserPath(path))
		if err != nil {
			return nil, err
		}
		if !validProjectID(id) {
			return nil, fmt.Errorf("invalid project ID %q for %s", id, path)
		}
		result[normalized] = id
	}
	return result, nil
}

func securePrivateGitTree(root string) error {
	if err := securePrivateDir(root); err != nil {
		return err
	}
	return filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("refusing symlink in private snapshot storage: %s", path)
		}
		mode := os.FileMode(0o600)
		if info.IsDir() {
			mode = 0o700
		}
		return os.Chmod(path, mode)
	})
}

func securePrivateDir(root string) error {
	info, err := os.Lstat(root)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("expected a real directory at %s", root)
	}
	return os.Chmod(root, 0o700)
}

func notifySnapshotFailure() {
	script := "display notification \"Project snapshot failed; review the LaunchAgent error log.\" with title \"Project snapshot\""
	_, _ = exec.Command("/usr/bin/osascript", "-e", script).Output()
}

func parseRestore(args []string) ([]string, []string, error) {
	var remaining, values []string
	for index := 0; index < len(args); index++ {
		arg := args[index]
		if arg == "--restore" || strings.HasPrefix(arg, "--restore=") {
			if len(values) > 0 {
				return nil, nil, errors.New("--restore may only be specified once")
			}
			if strings.HasPrefix(arg, "--restore=") {
				values = append(values, strings.TrimPrefix(arg, "--restore="))
			} else {
				index++
				if index >= len(args) {
					return nil, nil, errors.New("--restore requires STORE REF DESTINATION")
				}
				values = append(values, args[index])
			}
			for len(values) < 3 {
				index++
				if index >= len(args) || strings.HasPrefix(args[index], "-") {
					return nil, nil, errors.New("--restore requires STORE REF DESTINATION")
				}
				values = append(values, args[index])
			}
			continue
		}
		remaining = append(remaining, arg)
	}
	return remaining, values, nil
}

func parseRestoreRemote(args []string) ([]string, []string, error) {
	var remaining, values []string
	for index := 0; index < len(args); index++ {
		arg := args[index]
		if arg == "--restore-remote" || strings.HasPrefix(arg, "--restore-remote=") {
			if len(values) > 0 {
				return nil, nil, errors.New("--restore-remote may only be specified once")
			}
			if strings.HasPrefix(arg, "--restore-remote=") {
				values = append(values, strings.TrimPrefix(arg, "--restore-remote="))
			} else {
				index++
				if index >= len(args) {
					return nil, nil, errors.New("--restore-remote requires REF DESTINATION")
				}
				values = append(values, args[index])
			}
			for len(values) < 2 {
				index++
				if index >= len(args) || strings.HasPrefix(args[index], "-") {
					return nil, nil, errors.New("--restore-remote requires REF DESTINATION")
				}
				values = append(values, args[index])
			}
			continue
		}
		remaining = append(remaining, arg)
	}
	return remaining, values, nil
}

func runSnapshot(args []string) int {
	args, restoreRemote, err := parseRestoreRemote(args)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	remaining, restore, err := parseRestore(args)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	flags := flag.NewFlagSet("project-snapshot", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	rootFlag := flags.String("root", "", "projects root; defaults to NIX_CONFIG_PATH_PROJECTS")
	storeFlag := flags.String("snapshot-root", "", "snapshot storage; defaults to XDG data home")
	remoteSSHHost := flags.String("remote-ssh-host", os.Getenv("PROJECT_SNAPSHOT_REMOTE_SSH_HOST"), "SSH config alias for the snapshot target")
	remoteRoot := flags.String("remote-root", os.Getenv("PROJECT_SNAPSHOT_REMOTE_ROOT"), "absolute path for per-project remote repositories")
	hostID := flags.String("host-id", os.Getenv("PROJECT_SNAPSHOT_HOST_ID"), "stable host identifier used in remote repository paths")
	projectOverridesJSON := flags.String("project-id-overrides", os.Getenv("PROJECT_SNAPSHOT_PROJECT_ID_OVERRIDES_JSON"), "JSON object mapping normalized project paths to stable IDs")
	projectIDFlag := flags.String("project-id", "", "project ID required for remote restore")
	retention := flags.Int("retention-days", 30, "snapshot ref retention in days")
	list := flags.Bool("list", false, "list retained snapshots")
	check := flags.Bool("check", false, "verify local snapshot stores and compare refs with the optional remote")
	if err := flags.Parse(remaining); err != nil || flags.NArg() != 0 {
		return 2
	}
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		dataHome = filepath.Join(os.Getenv("HOME"), ".local", "share")
	}
	backupRoot := *storeFlag
	if backupRoot == "" {
		backupRoot = filepath.Join(dataHome, "project-snapshots")
	}
	backupRoot = expandUserPath(backupRoot)
	backupRoot, err = resolvePath(backupRoot)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	remoteProvided := *remoteSSHHost != "" || *remoteRoot != "" || *hostID != ""
	remoteEnabled := *remoteSSHHost != "" && *remoteRoot != "" && *hostID != ""
	if remoteProvided && !remoteEnabled {
		fmt.Fprintln(os.Stderr, "remote snapshot target requires --remote-ssh-host, --remote-root, and --host-id together")
		return 2
	}
	projectOverrides, err := decodeProjectOverrides(*projectOverridesJSON)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	if *list && *check {
		fmt.Fprintln(os.Stderr, "--list and --check cannot be used together")
		return 2
	}
	if *check {
		var err error
		if remoteEnabled {
			err = checkSnapshotsWithTarget(os.Stdout, backupRoot, *remoteSSHHost, *remoteRoot, *hostID)
		} else {
			err = checkSnapshots(os.Stdout, backupRoot, "")
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "Snapshot check failed: %v\n", err)
			return 1
		}
		return 0
	}
	if *list {
		var err error
		if remoteEnabled {
			err = listSnapshotsWithTarget(backupRoot, *remoteSSHHost, *remoteRoot, *hostID)
		} else {
			err = listSnapshots(backupRoot, "")
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		return 0
	}
	if len(restore) == 3 {
		if err := restoreSnapshot(expandUserPath(restore[0]), restore[1], expandUserPath(restore[2])); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
			return 1
		}
		return 0
	}
	if len(restoreRemote) == 2 {
		if !remoteEnabled || !validProjectID(*projectIDFlag) {
			fmt.Fprintln(os.Stderr, "remote restore requires a configured Git target and --project-id")
			return 2
		}
		remote, _, err := remoteRepositoryURL(*remoteSSHHost, *remoteRoot, *hostID, *projectIDFlag)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 2
		}
		if err := restoreRemoteSnapshot(backupRoot, remote, restoreRemote[0], expandUserPath(restoreRemote[1])); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
			return 1
		}
		return 0
	}
	root := *rootFlag
	if root == "" {
		root = os.Getenv("NIX_CONFIG_PATH_PROJECTS")
	}
	if root == "" {
		fmt.Fprintln(os.Stderr, "set NIX_CONFIG_PATH_PROJECTS or pass --root")
		return 2
	}
	root = expandUserPath(root)
	root, err = resolvePath(root)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	if !isDirectory(root) {
		fmt.Fprintf(os.Stderr, "projects root is not a directory: %s\n", root)
		return 2
	}
	if *retention < 1 {
		fmt.Fprintln(os.Stderr, "--retention-days must be at least 1")
		return 2
	}
	inside, err := safeInside(backupRoot, root)
	if err != nil || inside {
		fmt.Fprintln(os.Stderr, "snapshot storage must be outside the projects root")
		return 2
	}

	oldUmask := syscall.Umask(0o077)
	defer syscall.Umask(oldUmask)
	if err := os.MkdirAll(backupRoot, 0o700); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	if err := os.Chmod(backupRoot, 0o700); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	inside, err = safeInside(backupRoot, root)
	if err != nil || inside {
		fmt.Fprintln(os.Stderr, "snapshot storage resolves inside the projects root")
		return 2
	}

	lockPath := filepath.Join(backupRoot, ".snapshot.lock")
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		notifySnapshotFailure()
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		if errors.Is(err, syscall.EWOULDBLOCK) || errors.Is(err, syscall.EAGAIN) {
			fmt.Println("Another project snapshot run is active; skipped.")
			return 0
		}
		notifySnapshotFailure()
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	now := time.Now().UTC()
	targets, err := allWorktrees(root, defaultWorkers())
	if err != nil {
		notifySnapshotFailure()
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	saved, skipped, failed := 0, 0, 0
	for _, target := range targets {
		if !target.entry.Available || target.entry.Prunable || target.entry.Bare {
			skipped++
			fmt.Printf("SKIP %s: unavailable or prunable worktree\n", target.path)
			continue
		}
		projectID, idErr := projectIDForPath(target.repo, projectOverrides)
		if idErr != nil {
			failed++
			fmt.Fprintf(os.Stderr, "ERROR %s: %v\n", target.path, idErr)
			continue
		}
		status, detail, err := snapshotOneWithID(target.path, target.repo, backupRoot, root, *retention, now, projectID)
		if err != nil {
			failed++
			fmt.Fprintf(os.Stderr, "ERROR %s: %v\n", target.path, err)
			continue
		}
		fmt.Printf("%s %s\n", strings.ToUpper(status), detail)
		if status == "saved" {
			saved++
		} else {
			skipped++
		}
	}
	if !remoteEnabled {
		fmt.Println("REMOTE disabled")
	}
	pruned := 0
	stores, _ := filepath.Glob(filepath.Join(backupRoot, "*.git"))
	for _, store := range stores {
		count, err := pruneOldSnapshots(store, *retention, now)
		if err != nil {
			failed++
			fmt.Fprintf(os.Stderr, "ERROR pruning %s: %v\n", store, err)
			continue
		}
		pruned += count
	}
	if remoteEnabled {
		for _, store := range stores {
			remote, remotePath, remoteErr := remoteForStore(store, *remoteSSHHost, *remoteRoot, *hostID)
			if remoteErr == nil {
				remoteErr = provisionSSHRepository(*remoteSSHHost, remotePath)
			}
			if remoteErr == nil {
				_, _, remoteErr = syncSnapshotRefs(store, remote)
			}
			if remoteErr != nil {
				failed++
				fmt.Fprintf(os.Stderr, "REMOTE ERROR %s: %v\n", store, remoteErr)
			}
		}
	}
	if failed > 0 {
		notifySnapshotFailure()
	}
	fmt.Printf("Snapshot run complete: saved=%d, skipped=%d, failed=%d, expired=%d\n", saved, skipped, failed, pruned)
	if failed > 0 {
		return 1
	}
	return 0
}
