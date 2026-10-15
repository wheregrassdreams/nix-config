package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func runAudit() int {
	root := os.Getenv("NIX_CONFIG_PATH_PROJECTS")
	if root == "" {
		fmt.Fprintln(os.Stderr, "NIX_CONFIG_PATH_PROJECTS is not set")
		return 2
	}
	inactiveDays := 90
	if value := os.Getenv("PROJECTS_INACTIVE_AFTER_DAYS"); value != "" {
		parsed, err := strconv.Atoi(value)
		if err != nil || parsed < 1 {
			fmt.Fprintln(os.Stderr, "PROJECTS_INACTIVE_AFTER_DAYS must be a positive integer")
			return 2
		}
		inactiveDays = parsed
	}
	value, err := scan(root, inactiveDays, defaultWorkers())
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	current := make(map[string]finding, len(value.Findings))
	for _, item := range value.Findings {
		reasons := append([]string(nil), item.Reasons...)
		sort.Strings(reasons)
		current[item.Path+":"+strings.Join(reasons, ",")] = item
	}

	stateHome := os.Getenv("XDG_STATE_HOME")
	if stateHome == "" {
		stateHome = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	statePath := filepath.Join(stateHome, "projects", "last-findings.json")
	previous, hasBaseline := readFindingState(statePath)
	if err := writeFindingState(statePath, current); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	if hasBaseline {
		added := 0
		for key := range current {
			if _, found := previous[key]; !found {
				added++
			}
		}
		if added > 0 {
			notifyNewFindings(added)
		}
	}
	return 0
}

func readFindingState(path string) (map[string]struct{}, bool) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	var keys []string
	if err := json.Unmarshal(data, &keys); err != nil {
		return nil, false
	}
	result := make(map[string]struct{}, len(keys))
	for _, key := range keys {
		result[key] = struct{}{}
	}
	return result, true
}

func writeFindingState(path string, current map[string]finding) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	keys := make([]string, 0, len(current))
	for key := range current {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	data, err := json.MarshalIndent(keys, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	file, err := os.CreateTemp(filepath.Dir(path), ".last-findings-*")
	if err != nil {
		return err
	}
	temporary := file.Name()
	defer os.Remove(temporary)
	if _, err := file.Write(data); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(temporary, path)
}

func notifyNewFindings(count int) {
	message := fmt.Sprintf("%d new project review finding(s); see the weekly scan log.", count)
	script := "display notification " + strconv.Quote(message) + " with title " + strconv.Quote("Project inventory")
	_ = exec.Command("/usr/bin/osascript", "-e", script).Run()
}
