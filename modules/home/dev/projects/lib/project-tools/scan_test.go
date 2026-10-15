package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func runScanGit(t *testing.T, directory string, args ...string) string {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}
	return strings.TrimSpace(string(output))
}

func TestScanJSONContractIncludesGitFactsAndActivity(t *testing.T) {
	root := t.TempDir()
	repoPath := filepath.Join(root, "sample")
	if err := os.MkdirAll(repoPath, 0o755); err != nil {
		t.Fatal(err)
	}
	runScanGit(t, repoPath, "init", "--quiet")
	runScanGit(t, repoPath, "config", "user.name", "Scan Test")
	runScanGit(t, repoPath, "config", "user.email", "scan-test@localhost")
	if err := os.WriteFile(filepath.Join(repoPath, "tracked.txt"), []byte("content\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runScanGit(t, repoPath, "add", "tracked.txt")
	runScanGit(t, repoPath, "commit", "--quiet", "-m", "initial")
	runScanGit(t, repoPath, "remote", "add", "origin", "https://user:secret@example.invalid/repo.git?token=secret")
	runScanGit(t, repoPath, "config", "remote.origin.pushurl", "https://pushuser:pushsecret@example.invalid/repo.git?token=pushsecret")
	runScanGit(t, repoPath, "remote", "add", "upstream", "git@example.invalid:other/repo.git")

	result, err := scan(root, 90, 2)
	if err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(result)
	if err != nil {
		t.Fatal(err)
	}
	var decoded struct {
		SchemaVersion int `json:"schemaVersion"`
		Repositories  []struct {
			LastCommitAt       *string  `json:"lastCommitAt"`
			LastFileActivityAt *string  `json:"lastFileActivityAt"`
			ActivityAgeDays    *int     `json:"activityAgeDays"`
			Remotes            []remote `json:"remotes"`
		} `json:"repositories"`
	}
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded.SchemaVersion != 1 {
		t.Fatalf("schemaVersion = %v, want 1", decoded.SchemaVersion)
	}
	if len(decoded.Repositories) != 1 {
		t.Fatalf("repositories = %d, want 1", len(decoded.Repositories))
	}
	repository := decoded.Repositories[0]
	if repository.LastCommitAt == nil || repository.LastFileActivityAt == nil || repository.ActivityAgeDays == nil {
		t.Fatalf("activity fields missing from report: %#v", repository)
	}
	if len(repository.Remotes) != 2 {
		t.Fatalf("remotes = %d, want 2", len(repository.Remotes))
	}
	var foundOrigin, foundUpstream bool
	for _, item := range repository.Remotes {
		urls := strings.Join(item.FetchURLs, " ")
		switch item.Name {
		case "origin":
			foundOrigin = true
			if strings.Contains(urls, "secret") || urls != "https://example.invalid/repo.git" {
				t.Errorf("origin URL was not safely normalized: %q", urls)
			}
			pushURLs := strings.Join(item.PushURLs, " ")
			if strings.Contains(pushURLs, "secret") || pushURLs != "https://example.invalid/repo.git" {
				t.Errorf("origin push URL was not safely normalized: %q", pushURLs)
			}
		case "upstream":
			foundUpstream = true
			if urls != "git@example.invalid:other/repo.git" {
				t.Errorf("SSH remote URL changed unexpectedly: %q", urls)
			}
		}
	}
	if !foundOrigin || !foundUpstream {
		t.Fatalf("remote names missing: origin=%v upstream=%v", foundOrigin, foundUpstream)
	}
	if strings.Contains(string(encoded), "secret") {
		t.Fatalf("report leaked remote credentials: %s", encoded)
	}
}

func TestParseWorktreePorcelainHandlesNewlinePath(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "tree\nwith-newline")
	if err := os.Mkdir(path, 0o755); err != nil {
		t.Fatal(err)
	}
	porcelain := []byte("worktree " + path + "\x00HEAD abc123\x00branch refs/heads/feature/topic\x00\x00")
	worktrees, err := parseWorktreePorcelain(porcelain, root, context.Background(), 1, func(_ string, _ ...string) ([]byte, error) {
		return nil, nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(worktrees) != 1 || worktrees[0].Path != path || worktrees[0].Branch != "feature/topic" || !worktrees[0].Available {
		t.Fatalf("parsed worktree = %#v", worktrees)
	}
}

func TestParseWorktreesUsesGitPorcelainZ(t *testing.T) {
	root := t.TempDir()
	repoPath := filepath.Join(root, "repository")
	if err := os.MkdirAll(repoPath, 0o755); err != nil {
		t.Fatal(err)
	}
	runScanGit(t, repoPath, "init", "--quiet", "-b", "main")
	runScanGit(t, repoPath, "config", "user.name", "Scan Test")
	runScanGit(t, repoPath, "config", "user.email", "scan-test@localhost")
	if err := os.WriteFile(filepath.Join(repoPath, "tracked.txt"), []byte("content\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runScanGit(t, repoPath, "add", "tracked.txt")
	runScanGit(t, repoPath, "commit", "--quiet", "-m", "initial")
	linkedPath := filepath.Join(root, "linked\nworktree")
	runScanGit(t, repoPath, "worktree", "add", "--quiet", "-b", "feature/test", linkedPath)

	s := scanner{ctx: context.Background(), root: root, workers: 2, gitSlots: make(chan struct{}, 2)}
	worktrees, err := s.parseWorktrees(repoPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(worktrees) != 2 {
		t.Fatalf("worktrees = %d, want 2: %#v", len(worktrees), worktrees)
	}
	var foundPrimary, foundLinked bool
	var linkedDetails string
	for _, tree := range worktrees {
		if tree.Primary && canonical(tree.Path) == canonical(repoPath) {
			foundPrimary = true
		}
		if !tree.Primary && canonical(tree.Path) == canonical(linkedPath) && tree.Branch == "feature/test" && tree.Available && tree.Dirty != nil && !*tree.Dirty {
			foundLinked = true
		}
		if !tree.Primary {
			dirty := "nil"
			if tree.Dirty != nil {
				dirty = fmt.Sprint(*tree.Dirty)
			}
			linkedDetails = fmt.Sprintf("path=%q expected=%q branch=%q available=%v dirty=%s", tree.Path, linkedPath, tree.Branch, tree.Available, dirty)
		}
	}
	if !foundPrimary || !foundLinked {
		t.Fatalf("primary=%v linked=%v linked details=%s", foundPrimary, foundLinked, linkedDetails)
	}
}
