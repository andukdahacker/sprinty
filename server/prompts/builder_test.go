package prompts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ducdo/sprinty/server/providers"
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
		"mode-directive.md":    "Directive mode: provide confident action steps.",
		"safety.md":            "Classify safety: green/yellow/orange/red.",
		"mood.md":              "Select mood: welcoming/warm/focused/gentle.",
		"tagging.md":           "Tag domains: career, finance, etc.",
		"cultural.md":          "Cultural context.",
		"context-injection.md": "Coach name: {{coach_name}}. Engagement: {{engagement_level}}. Moods: {{recent_moods}}. MsgLen: {{avg_message_length}}. Sessions: {{session_count}}. Gap: {{last_session_gap}}. Intensity: {{recent_session_intensity}}.",
		"mode-transitions.md": "Mode transitions: analyze user intent.",
		"challenger.md":       "Challenger capability: push back constructively.",
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

	if len(b.sections) != 10 {
		t.Errorf("expected 10 sections, got %d", len(b.sections))
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

	prompt := b.Build("discovery", "Luna", nil)

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

	prompt := b.Build("discovery", "", nil)

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

	prompt := b.Build("unknown_mode", "Luna", nil)

	if !strings.Contains(prompt, "Discovery mode") {
		t.Error("expected unknown mode to fall back to discovery")
	}
}

func TestBuilder_Build_DiscoveryMode_IncludesDiscoverySection(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil)

	if !strings.Contains(prompt, "Discovery mode") {
		t.Error("expected discovery section in discovery mode prompt")
	}
}

func TestBuilder_Build_DirectiveMode(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("directive", "Luna", nil)

	if !strings.Contains(prompt, "Directive mode") {
		t.Error("expected directive mode section in directive mode prompt")
	}
	if !strings.Contains(prompt, "You are Luna, a coach.") {
		t.Error("expected base persona with coach name injected")
	}
	if !strings.Contains(prompt, "Classify safety") {
		t.Error("expected safety section")
	}
}

func TestBuilder_Build_DirectiveMode_ExcludesDiscovery(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("directive", "Luna", nil)

	if strings.Contains(prompt, "Discovery mode") {
		t.Error("expected discovery section to be absent in directive mode")
	}
	if !strings.Contains(prompt, "Directive mode") {
		t.Error("expected directive section present in directive mode")
	}
}

func TestBuilder_Build_IncludesModeTransitions(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	for _, mode := range []string{"discovery", "directive", "unknown"} {
		prompt := b.Build(mode, "Luna", nil)
		if !strings.Contains(prompt, "Mode transitions") {
			t.Errorf("expected mode-transitions section in %s mode prompt", mode)
		}
	}
}

func TestBuilder_Build_IncludesChallenger(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	for _, mode := range []string{"discovery", "directive", "unknown"} {
		prompt := b.Build(mode, "Luna", nil)
		if !strings.Contains(prompt, "Challenger capability") {
			t.Errorf("expected challenger section in %s mode prompt", mode)
		}
	}
}

func TestBuilder_Build_IncludesCulturalSection(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil)

	if !strings.Contains(prompt, "Cultural context") {
		t.Error("expected cultural section in assembled prompt")
	}
}

func TestBuilder_Build_WithUserState_InjectsContext(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	gap := 12
	us := &providers.UserState{
		EngagementLevel:        "high",
		RecentMoods:            []string{"warm", "focused"},
		AvgMessageLength:       "medium",
		SessionCount:           5,
		LastSessionGapHours:    &gap,
		RecentSessionIntensity: "moderate",
	}

	prompt := b.Build("discovery", "Luna", us)

	if !strings.Contains(prompt, "Engagement: high") {
		t.Error("expected engagement level in prompt")
	}
	if !strings.Contains(prompt, "Moods: warm, focused") {
		t.Error("expected recent moods in prompt")
	}
	if !strings.Contains(prompt, "MsgLen: medium") {
		t.Error("expected avg message length in prompt")
	}
	if !strings.Contains(prompt, "Sessions: 5") {
		t.Error("expected session count in prompt")
	}
	if !strings.Contains(prompt, "Gap: 12h") {
		t.Error("expected last session gap in prompt")
	}
	if !strings.Contains(prompt, "Intensity: moderate") {
		t.Error("expected session intensity in prompt")
	}
}

func TestBuilder_Build_WithNilUserState_UsesDefaults(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil)

	if !strings.Contains(prompt, "Engagement: unknown") {
		t.Error("expected unknown engagement level when userState is nil")
	}
	if !strings.Contains(prompt, "Gap: unknown") {
		t.Error("expected unknown gap when userState is nil")
	}
}
