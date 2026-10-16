# brew-state-sync

This source is vendored into the Homebrew capability so the Nix build does not
depend on a sibling checkout. Keep it synchronized with the standalone
`brew-state-diff` project when its implementation changes. It intentionally
uses only the Go standard library.
