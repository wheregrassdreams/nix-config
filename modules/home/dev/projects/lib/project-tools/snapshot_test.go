package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func runGitTest(t *testing.T, directory string, args ...string) string {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}
	return strings.TrimSpace(string(output))
}

func makeSnapshotFixture(t *testing.T) (string, string, string) {
	t.Helper()
	root := t.TempDir()
	projects := filepath.Join(root, "projects")
	repo := filepath.Join(projects, "tiny-project")
	storeRoot := filepath.Join(root, "local-snapshots")
	if err := os.MkdirAll(repo, 0o755); err != nil {
		t.Fatal(err)
	}
	runGitTest(t, repo, "init", "--quiet")
	runGitTest(t, repo, "config", "user.name", "Snapshot Test")
	runGitTest(t, repo, "config", "user.email", "snapshot-test@localhost")
	tracked := filepath.Join(repo, "tracked.txt")
	if err := os.WriteFile(tracked, []byte("before\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runGitTest(t, repo, "add", "tracked.txt")
	runGitTest(t, repo, "commit", "--quiet", "-m", "initial")
	if err := os.WriteFile(tracked, []byte("after\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, "untracked.txt"), []byte("new file\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return projects, repo, storeRoot
}

func findSnapshotStore(t *testing.T, root string) string {
	t.Helper()
	stores, err := filepath.Glob(filepath.Join(root, "*.git"))
	if err != nil || len(stores) != 1 {
		t.Fatalf("expected one snapshot store, got %v, error %v", stores, err)
	}
	return stores[0]
}

func TestSnapshotRemoteRoundTripAndOfflineRetry(t *testing.T) {
	projects, repo, storeRoot := makeSnapshotFixture(t)
	status, _, err := snapshotOne(repo, repo, storeRoot, projects, 30, time.Now().UTC())
	if err != nil || status != "saved" {
		t.Fatalf("snapshotOne = %q, %v", status, err)
	}
	store := findSnapshotStore(t, storeRoot)
	refs, err := bareGit(store, nil, "for-each-ref", "--format=%(refname)", snapshotNamespace)
	if err != nil || strings.TrimSpace(refs.stdout) == "" {
		t.Fatalf("local snapshot was not retained: %q, %v", refs.stdout, err)
	}
	ref := strings.TrimSpace(refs.stdout)

	missingRemote := filepath.Join(t.TempDir(), "not-yet-created.git")
	if _, _, err := syncSnapshotRefsValidated(store, missingRemote); err == nil {
		t.Fatal("expected first remote attempt to fail")
	}
	if _, err := bareGit(store, nil, "show-ref", "--verify", ref); err != nil {
		t.Fatalf("offline failure lost the local snapshot: %v", err)
	}

	remote := filepath.Join(t.TempDir(), "remote.git")
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", remote); err != nil {
		t.Fatal(err)
	}
	synced, pending, err := syncSnapshotRefsValidated(store, remote)
	if err != nil || pending != 0 || synced != 1 {
		t.Fatalf("retry sync = synced %d, pending %d, err %v", synced, pending, err)
	}
	remoteRefs, err := bareGit(remote, nil, "for-each-ref", "--format=%(refname)")
	if err != nil || strings.TrimSpace(remoteRefs.stdout) != ref {
		t.Fatalf("remote contains unexpected refs: %q, %v", remoteRefs.stdout, err)
	}
	if _, err := bareGit(remote, nil, "show-ref", "--verify", "refs/heads/main"); err == nil {
		t.Fatal("snapshot push created a project branch on the remote")
	}

	if err := os.RemoveAll(store); err != nil {
		t.Fatal(err)
	}
	cache := filepath.Join(storeRoot, "remote-cache.git")
	if err := os.MkdirAll(cache, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", cache); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(storeRoot, 0o777); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(cache, 0o777); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(filepath.Join(cache, "config"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(filepath.Join(cache, "objects"), 0o755); err != nil {
		t.Fatal(err)
	}
	destination := filepath.Join(t.TempDir(), "restored")
	if err := restoreRemoteSnapshotFrom(storeRoot, remote, ref, destination); err != nil {
		t.Fatal(err)
	}
	var checkOutput bytes.Buffer
	if err := checkSnapshotsUsing(&checkOutput, storeRoot, remote, queryRemoteSnapshotRefs); err != nil {
		t.Fatalf("snapshot check failed for healthy local and remote stores: %v\n%s", err, checkOutput.String())
	}
	if !strings.Contains(checkOutput.String(), "remote=matches") {
		t.Fatalf("snapshot check did not report remote parity: %s", checkOutput.String())
	}
	for _, path := range []string{storeRoot, cache, filepath.Join(cache, "config")} {
		info, err := os.Stat(path)
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode().Perm()&0o077 != 0 {
			t.Errorf("snapshot storage path %s has group/world permissions %04o", path, info.Mode().Perm())
		}
	}
	if err := filepath.WalkDir(cache, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if info.Mode().Perm()&0o077 != 0 {
			t.Errorf("remote cache entry %s has group/world permissions %04o", path, info.Mode().Perm())
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	var objects []string
	if err := filepath.WalkDir(filepath.Join(cache, "objects"), func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if !entry.IsDir() {
			objects = append(objects, path)
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if len(objects) == 0 {
		t.Fatal("expected fetched Git object files")
	}
	for _, object := range objects {
		info, err := os.Stat(object)
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode().Perm()&0o077 != 0 {
			t.Errorf("Git object %s has group/world permissions %04o", object, info.Mode().Perm())
		}
	}
	if got, err := os.ReadFile(filepath.Join(destination, "tracked.txt")); err != nil || string(got) != "after\n" {
		t.Fatalf("restored tracked content = %q, %v", got, err)
	}
	if got, err := os.ReadFile(filepath.Join(destination, "untracked.txt")); err != nil || string(got) != "new file\n" {
		t.Fatalf("restored untracked content = %q, %v", got, err)
	}
	parents := strings.Fields(runGitTest(t, destination, "rev-list", "--parents", "-n", "1", "HEAD"))
	if len(parents) != 1 {
		t.Fatalf("first snapshot should be a root commit, not retain source history: %v", parents)
	}
	metadata := runGitTest(t, destination, "show", "-s", "--format=%(trailers:key=Source-HEAD,valueonly)", "HEAD")
	if metadata == "" {
		t.Fatal("snapshot commit should record the source HEAD in its trailers")
	}
}

func TestRestoreValidationRejectsNonSnapshotRefs(t *testing.T) {
	_, repo, storeRoot := makeSnapshotFixture(t)
	status, _, err := snapshotOne(repo, repo, storeRoot, filepath.Dir(repo), 30, time.Now().UTC())
	if err != nil || status != "saved" {
		t.Fatalf("snapshotOne = %q, %v", status, err)
	}
	store := findSnapshotStore(t, storeRoot)
	destination := filepath.Join(t.TempDir(), "restore")
	if err := restoreSnapshot(store, "refs/heads/main", destination); err == nil {
		t.Fatal("restoreSnapshot accepted a non-snapshot ref")
	}
	if _, err := os.Stat(destination); !os.IsNotExist(err) {
		t.Fatalf("rejected restore created destination: %v", err)
	}
	actualDestination := filepath.Join(t.TempDir(), "actual")
	if err := os.Mkdir(actualDestination, 0o755); err != nil {
		t.Fatal(err)
	}
	symlinkDestination := filepath.Join(t.TempDir(), "restore-link")
	if err := os.Symlink(actualDestination, symlinkDestination); err != nil {
		t.Fatal(err)
	}
	if err := restoreSnapshot(store, "refs/nix-project-snapshots/../heads/main", symlinkDestination); err == nil {
		t.Fatal("restoreSnapshot accepted an invalid ref and symlink destination")
	}
	entries, err := os.ReadDir(actualDestination)
	if err != nil || len(entries) != 0 {
		t.Fatalf("rejected symlink restore modified target: entries=%v err=%v", entries, err)
	}
}

func TestSnapshotCheckDetectsRemoteRefMismatch(t *testing.T) {
	projects, repo, storeRoot := makeSnapshotFixture(t)
	status, _, err := snapshotOne(repo, repo, storeRoot, projects, 30, time.Now().UTC())
	if err != nil || status != "saved" {
		t.Fatalf("snapshotOne = %q, %v", status, err)
	}
	store := findSnapshotStore(t, storeRoot)
	refs, err := bareGit(store, nil, "for-each-ref", "--format=%(refname)", snapshotNamespace)
	if err != nil {
		t.Fatal(err)
	}
	ref := strings.TrimSpace(refs.stdout)
	remote := filepath.Join(t.TempDir(), "remote.git")
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", remote); err != nil {
		t.Fatal(err)
	}
	if _, err := bareGit(store, nil, "push", remote, ref+":"+ref); err != nil {
		t.Fatal(err)
	}
	localObject, err := bareGit(store, nil, "rev-parse", ref)
	if err != nil {
		t.Fatal(err)
	}
	identity := map[string]string{
		"GIT_AUTHOR_NAME": "Snapshot Test", "GIT_AUTHOR_EMAIL": "snapshot-test@localhost",
		"GIT_COMMITTER_NAME": "Snapshot Test", "GIT_COMMITTER_EMAIL": "snapshot-test@localhost",
	}
	otherCommit, err := bareGit(store, identity, "commit-tree", strings.TrimSpace(mustTree(t, store, strings.TrimSpace(localObject.stdout))), "-m", "different snapshot object")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := bareGit(store, nil, "update-ref", "refs/heads/test-other", strings.TrimSpace(otherCommit.stdout)); err != nil {
		t.Fatal(err)
	}
	if _, err := bareGit(store, nil, "push", remote, "refs/heads/test-other:refs/heads/test-other"); err != nil {
		t.Fatal(err)
	}
	if _, err := bareGit(remote, nil, "update-ref", ref, strings.TrimSpace(otherCommit.stdout)); err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := checkSnapshotsUsing(&output, storeRoot, remote, queryRemoteSnapshotRefs); err == nil {
		t.Fatalf("snapshot check accepted a remote ref mismatch: %s", output.String())
	}
	if !strings.Contains(output.String(), "remote=mismatch") {
		t.Fatalf("snapshot check did not explain mismatch: %s", output.String())
	}
}

func mustTree(t *testing.T, store, commit string) string {
	t.Helper()
	tree, err := bareGit(store, nil, "rev-parse", "--verify", commit+"^{tree}")
	if err != nil {
		t.Fatal(err)
	}
	return strings.TrimSpace(tree.stdout)
}

func TestSnapshotRemoteSchemes(t *testing.T) {
	for _, remote := range []string{
		"https://user:secret@example.invalid/repo.git",
		"https://user@example.invalid/repo.git?token=secret",
		"http://snapshot-host/repo.git",
		"git://snapshot-host/repo.git",
		"file:///tmp/snapshots.git",
		"rsync://snapshot-host/repo.git",
		"user@:snapshot.git",
		"snapshot-host:",
	} {
		if err := validateRemoteURL(remote); err == nil {
			t.Errorf("validateRemoteURL(%q) accepted an unsupported or malformed remote", remote)
		}
	}
	for _, remote := range []string{
		"https://example.invalid/user/snapshots.git",
		"ssh://git@example.invalid/snapshots.git",
		"git@example.invalid:/srv/git/snapshots.git",
		"snapshot-host:/srv/git/snapshots.git",
	} {
		if err := validateRemoteURL(remote); err != nil {
			t.Errorf("validateRemoteURL(%q) rejected a supported remote: %v", remote, err)
		}
	}
	if err := validateRemoteURL("ssh://git:secret@example.invalid/snapshots.git"); err == nil {
		t.Error("SSH URL with an embedded password should be rejected")
	}
}
