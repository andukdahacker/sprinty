package tests

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func loadFixture(t *testing.T, filename string) []byte {
	t.Helper()
	_, callerFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("failed to get caller file path")
	}
	fixtureDir := filepath.Join(filepath.Dir(callerFile), "..", "..", "docs", "fixtures")
	data, err := os.ReadFile(filepath.Join(fixtureDir, filename))
	if err != nil {
		t.Fatalf("failed to load fixture %s: %v", filename, err)
	}
	return data
}
