package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestSnapshotRemoteKindRequiresRemoteConfiguration(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	for _, name := range []string{
		"PROJECT_SNAPSHOT_REMOTE_SSH_HOST",
		"PROJECT_SNAPSHOT_REMOTE_ROOT",
		"PROJECT_SNAPSHOT_REMOTE_KIND",
		"PROJECT_SNAPSHOT_GITEA_API_URL",
		"PROJECT_SNAPSHOT_GITEA_ORGANIZATION",
		"PROJECT_SNAPSHOT_GITEA_TOKEN_FILE",
		"PROJECT_SNAPSHOT_HOST_ID",
	} {
		t.Setenv(name, "")
	}

	if status := runSnapshot([]string{"--remote-kind", "gitea"}); status != 2 {
		t.Fatalf("runSnapshot with an incomplete explicit remote target = %d, want 2", status)
	}
}

func TestGiteaRepositoryNamingAndURL(t *testing.T) {
	name, err := giteaRepositoryName("Mac_Book", "my.project_1")
	if err != nil || !strings.HasPrefix(name, "mac-book-my-project-1-") {
		t.Fatalf("giteaRepositoryName = %q, %v", name, err)
	}
	remote, path, err := giteaRepositoryURL("gitea-backups", "homelab-backups", "macbook", "abc123")
	if err != nil || !strings.HasPrefix(remote, "ssh://gitea-backups/homelab-backups/macbook-abc123-") || !strings.HasSuffix(remote, ".git") || !strings.HasPrefix(path, "/homelab-backups/macbook-abc123-") {
		t.Fatalf("giteaRepositoryURL = %q, %q, %v", remote, path, err)
	}
}

func TestGiteaRepositoryNameIsCollisionResistantAndBounded(t *testing.T) {
	first, err := giteaRepositoryName("mac_book", "project-name")
	if err != nil {
		t.Fatal(err)
	}
	second, err := giteaRepositoryName("mac-book", "project-name")
	if err != nil {
		t.Fatal(err)
	}
	if first == second {
		t.Fatalf("distinct IDs produced the same Gitea repository name %q", first)
	}

	long, err := giteaRepositoryName(strings.Repeat("host", 40), strings.Repeat("project", 40))
	if err != nil || len(long) > 100 {
		t.Fatalf("long Gitea repository name = %q (%d bytes), %v", long, len(long), err)
	}
	if _, err := giteaRepositoryName("---", "project"); err == nil {
		t.Fatal("expected punctuation-only host ID to be rejected")
	}
}

func TestProvisionGiteaRepositoryCreateAndExisting(t *testing.T) {
	token := filepath.Join(t.TempDir(), "token")
	expectedRepo, err := giteaRepositoryName("macbook", "project")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(token, []byte("test-token\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	created := false
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "token test-token" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		switch r.Method {
		case http.MethodPost:
			var payload struct {
				Name    string `json:"name"`
				Private bool   `json:"private"`
			}
			if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || payload.Name != expectedRepo || !payload.Private {
				http.Error(w, "invalid create payload", http.StatusBadRequest)
				return
			}
			if created {
				w.WriteHeader(http.StatusConflict)
				return
			}
			created = true
			w.WriteHeader(http.StatusCreated)
		case http.MethodGet:
			if r.URL.Path != "/api/v1/repos/homelab-backups/"+expectedRepo {
				http.NotFound(w, r)
				return
			}
			_, _ = w.Write([]byte(`{"private":true,"permissions":{"push":true}}`))
		default:
			http.Error(w, "unexpected method", http.StatusMethodNotAllowed)
		}
	}))
	defer server.Close()
	for i := 0; i < 2; i++ {
		if err := provisionGiteaRepositoryWithClient(server.Client(), server.URL, "homelab-backups", "macbook", "project", token); err != nil {
			t.Fatalf("provision attempt %d: %v", i+1, err)
		}
	}
}

func TestProvisionGiteaRepositoryRejectsMissingPushAccess(t *testing.T) {
	token := filepath.Join(t.TempDir(), "token")
	if err := os.WriteFile(token, []byte("test-token"), 0o600); err != nil {
		t.Fatal(err)
	}
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			w.WriteHeader(http.StatusConflict)
			return
		}
		_, _ = w.Write([]byte(`{"private":true,"permissions":{"push":false}}`))
	}))
	defer server.Close()
	if err := provisionGiteaRepositoryWithClient(server.Client(), server.URL, "homelab-backups", "macbook", "project", token); err == nil || !strings.Contains(err.Error(), "push permission") {
		t.Fatalf("expected push permission rejection, got %v", err)
	}
}

func TestProvisionGiteaRepositoryRejectsAPIError(t *testing.T) {
	token := filepath.Join(t.TempDir(), "token")
	if err := os.WriteFile(token, []byte("test-token"), 0o600); err != nil {
		t.Fatal(err)
	}
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "forbidden", http.StatusForbidden)
	}))
	defer server.Close()
	if err := provisionGiteaRepositoryWithClient(server.Client(), server.URL, "homelab-backups", "macbook", "project", token); err == nil || !strings.Contains(err.Error(), "HTTP 403") {
		t.Fatalf("expected API error, got %v", err)
	}
}

func TestProvisionGiteaRepositoryRejectsInvalidOrganization(t *testing.T) {
	err := provisionGiteaRepositoryWithClient(&http.Client{}, "https://gitea.example", "../other-org", "macbook", "project", "unused")
	if err == nil || !strings.Contains(err.Error(), "single path segment") {
		t.Fatalf("expected invalid organization rejection, got %v", err)
	}
}

func TestProvisionGiteaRepositoryRejectsCrossSchemeRedirect(t *testing.T) {
	token := filepath.Join(t.TempDir(), "token")
	if err := os.WriteFile(token, []byte("test-token"), 0o600); err != nil {
		t.Fatal(err)
	}
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://"+r.Host+r.URL.Path, http.StatusTemporaryRedirect)
	}))
	defer server.Close()
	err := provisionGiteaRepositoryWithClient(server.Client(), server.URL, "homelab-backups", "macbook", "project", token)
	if err == nil || !strings.Contains(err.Error(), "same HTTPS host") {
		t.Fatalf("expected HTTPS redirect rejection, got %v", err)
	}
}

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
	cache := filepath.Join(storeRoot, "remote-cache", "remote-cache.git")
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
	stores, err := projectSnapshotStores(storeRoot)
	if err != nil || len(stores) != 0 {
		t.Fatalf("restore cache was enumerated as a project store: %v, error %v", stores, err)
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

func TestProjectSnapshotStoresExcludeRestoreCache(t *testing.T) {
	root := t.TempDir()
	projectStore := filepath.Join(root, "demo-project.git")
	legacyCache := filepath.Join(root, "remote-cache.git")
	for _, store := range []string{projectStore, legacyCache} {
		if _, err := gitCommand(nil, "init", "--bare", "--quiet", store); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", filepath.Join(root, "remote-cache", "remote-cache.git")); err != nil {
		t.Fatal(err)
	}
	stores, err := projectSnapshotStores(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(stores) != 1 || stores[0] != projectStore {
		t.Fatalf("project stores = %v, want only %s", stores, projectStore)
	}
}

func TestSnapshotSyncSeedsExistingRemoteBeforeAppend(t *testing.T) {
	_, repo, storeRoot := makeSnapshotFixture(t)
	status, _, err := snapshotOne(repo, repo, storeRoot, filepath.Dir(repo), 30, time.Now().UTC())
	if err != nil || status != "saved" {
		t.Fatalf("initial snapshot = %q, %v", status, err)
	}
	originalStore := findSnapshotStore(t, storeRoot)
	remote := filepath.Join(t.TempDir(), "remote.git")
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", remote); err != nil {
		t.Fatal(err)
	}
	if _, _, err := syncSnapshotRefsValidated(originalStore, remote); err != nil {
		t.Fatal(err)
	}
	originalTip, err := bareGit(remote, nil, "rev-parse", "--verify", snapshotNamespace)
	if err != nil {
		t.Fatal(err)
	}
	emptyLocal := filepath.Join(t.TempDir(), "empty-local.git")
	if _, err := gitCommand(nil, "init", "--bare", "--quiet", emptyLocal); err != nil {
		t.Fatal(err)
	}
	if _, _, err := syncSnapshotRefsValidated(emptyLocal, remote); err != nil {
		t.Fatalf("seed empty local history: %v", err)
	}
	seeded, err := bareGit(emptyLocal, nil, "rev-parse", "--verify", snapshotNamespace)
	if err != nil || strings.TrimSpace(seeded.stdout) != strings.TrimSpace(originalTip.stdout) {
		t.Fatalf("seeded tip = %q, want %q (error %v)", strings.TrimSpace(seeded.stdout), strings.TrimSpace(originalTip.stdout), err)
	}
	tree, err := bareGit(emptyLocal, nil, "rev-parse", snapshotNamespace+"^{tree}")
	if err != nil {
		t.Fatal(err)
	}
	appended, err := bareGit(emptyLocal, map[string]string{"GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@example.invalid", "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@example.invalid"}, "commit-tree", strings.TrimSpace(tree.stdout), "-p", strings.TrimSpace(seeded.stdout), "-m", "appended snapshot")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := bareGit(emptyLocal, nil, "update-ref", snapshotNamespace, strings.TrimSpace(appended.stdout), strings.TrimSpace(seeded.stdout)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := syncSnapshotRefsValidated(emptyLocal, remote); err != nil {
		t.Fatalf("push appended timeline: %v", err)
	}
	parents, err := bareGit(remote, nil, "rev-list", "--parents", "-n", "1", snapshotNamespace)
	if err != nil || !strings.Contains(parents.stdout, strings.TrimSpace(originalTip.stdout)) {
		t.Fatalf("remote timeline lost prior tip %s: %q, error %v", strings.TrimSpace(originalTip.stdout), parents.stdout, err)
	}
}

func TestSnapshotSyncRejectsUnrelatedRemoteHistory(t *testing.T) {
	remote := filepath.Join(t.TempDir(), "remote.git")
	local := filepath.Join(t.TempDir(), "local.git")
	for _, store := range []string{remote, local} {
		if _, err := gitCommand(nil, "init", "--bare", "--quiet", store); err != nil {
			t.Fatal(err)
		}
	}
	for index, store := range []string{remote, local} {
		tree, err := bareGit(store, nil, "mktree")
		if err != nil {
			t.Fatal(err)
		}
		commit, err := bareGit(store, map[string]string{"GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@example.invalid", "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@example.invalid"}, "commit-tree", strings.TrimSpace(tree.stdout), "-m", fmt.Sprintf("independent timeline %d", index))
		if err != nil {
			t.Fatal(err)
		}
		if _, err := bareGit(store, nil, "update-ref", snapshotNamespace, strings.TrimSpace(commit.stdout)); err != nil {
			t.Fatal(err)
		}
	}
	remoteBefore, err := bareGit(remote, nil, "rev-parse", snapshotNamespace)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := syncSnapshotRefsValidated(local, remote); err == nil || !strings.Contains(err.Error(), "diverges") {
		t.Fatalf("unrelated history sync error = %v, want divergence refusal", err)
	}
	remoteAfter, err := bareGit(remote, nil, "rev-parse", snapshotNamespace)
	if err != nil || strings.TrimSpace(remoteAfter.stdout) != strings.TrimSpace(remoteBefore.stdout) {
		t.Fatalf("remote tip changed after divergence refusal: %q, error %v", remoteAfter.stdout, err)
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
