package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: project-tools <scan|audit|snapshot> [flags]")
		os.Exit(2)
	}

	var code int
	switch os.Args[1] {
	case "scan":
		code = runScan(os.Args[2:])
	case "audit":
		code = runAudit()
	case "snapshot":
		code = runSnapshot(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n", os.Args[1])
		code = 2
	}
	os.Exit(code)
}
