package prompts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setupTestSections(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	sectionsDir := filepath.Join(dir, "sections")
	if err := os.MkdirAll(sectionsDir, 0o755); err != nil {
		t.Fatalf("failed to create sections dir: %v", err)
	}

	files := map[string]string{
		"base-persona.md":      "You are {{coach_name}}, a coach.",
		"mode-discovery.md":    "Discovery mode: ask probing questions.",
		"safety.md":            "Classify safety: green/yellow/orange/red.",
		"mood.md":              "Select mood: welcoming/warm/focused/gentle.",
		"tagging.md":           "Tag domains: career, finance, etc.",
		"context-injection.md": "Coach name: {{coach_name}}.",
	}

	for name, content := range files {
		path := filepath.Join(sectionsDir, name)
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("failed to write %s: %v", name, err)
		}
	}

	return sectionsDir
}

func TestNewBuilder_LoadsSections(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	if len(b.sections) != 6 {
		t.Errorf("expected 6 sections, got %d", len(b.sections))
	}

	if b.contentHash == "" {
		t.Error("expected non-empty content hash")
	}
}

func TestNewBuilder_MissingSection(t *testing.T) {
	dir := t.TempDir()
	_, err := NewBuilder(dir)
	if err == nil {
		t.Fatal("expected error for missing sections")
	}
}

func TestBuilder_ContentHash_Stable(t *testing.T) {
	dir := setupTestSections(t)

	b1, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("first NewBuilder error: %v", err)
	}

	b2, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("second NewBuilder error: %v", err)
	}

	if b1.ContentHash() != b2.ContentHash() {
		t.Errorf("hash not stable: %q != %q", b1.ContentHash(), b2.ContentHash())
	}
}

func TestBuilder_ContentHash_ChangesOnUpdate(t *testing.T) {
	dir := setupTestSections(t)

	b1, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("first NewBuilder error: %v", err)
	}

	// Modify a section
	path := filepath.Join(dir, "safety.md")
	if err := os.WriteFile(path, []byte("Updated safety section."), 0o644); err != nil {
		t.Fatalf("failed to update section: %v", err)
	}

	b2, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("second NewBuilder error: %v", err)
	}

	if b1.ContentHash() == b2.ContentHash() {
		t.Error("hash should change when section content changes")
	}
}

func TestBuilder_Build_DiscoveryMode(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna")

	if !strings.Contains(prompt, "You are Luna, a coach.") {
		t.Error("expected base persona with coach name injected")
	}
	if !strings.Contains(prompt, "Discovery mode") {
		t.Error("expected discovery mode section")
	}
	if !strings.Contains(prompt, "Classify safety") {
		t.Error("expected safety section")
	}
	if !strings.Contains(prompt, "Select mood") {
		t.Error("expected mood section")
	}
	if !strings.Contains(prompt, "Tag domains") {
		t.Error("expected tagging section")
	}
	if !strings.Contains(prompt, "Coach name: Luna.") {
		t.Error("expected context injection with coach name")
	}
}

func TestBuilder_Build_DefaultCoachName(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "")

	if !strings.Contains(prompt, "You are Coach, a coach.") {
		t.Error("expected default coach name 'Coach'")
	}
}

func TestBuilder_Build_UnknownModeDefaultsToDiscovery(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("unknown_mode", "Luna")

	if !strings.Contains(prompt, "Discovery mode") {
		t.Error("expected unknown mode to fall back to discovery")
	}
}
