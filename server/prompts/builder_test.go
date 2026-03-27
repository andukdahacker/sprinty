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
		"context-injection.md": "{{sprint_context}} {{retrieved_memories}} Coach name: {{coach_name}}. Values: {{user_values}}. Goals: {{user_goals}}. Traits: {{user_traits}}. Domains: {{domain_states}}. Engagement: {{engagement_level}}. Moods: {{recent_moods}}. MsgLen: {{avg_message_length}}. Sessions: {{session_count}}. Gap: {{last_session_gap}}. Intensity: {{recent_session_intensity}}.",
		"mode-transitions.md": "Mode transitions: analyze user intent.",
		"challenger.md":       "Challenger capability: push back constructively.",
		"summarize.md":        "Summarize the coaching conversation.",
		"sprint-retro.md":     "Generate a narrative retrospective.",
		"check-in.md":         "Check-in mode: brief response.",
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

	if len(b.sections) != 13 {
		t.Errorf("expected 13 sections, got %d", len(b.sections))
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

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

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

	prompt := b.Build("discovery", "", nil, nil, "", nil)

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

	prompt := b.Build("unknown_mode", "Luna", nil, nil, "", nil)

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

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

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

	prompt := b.Build("directive", "Luna", nil, nil, "", nil)

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

	prompt := b.Build("directive", "Luna", nil, nil, "", nil)

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
		prompt := b.Build(mode, "Luna", nil, nil, "", nil)
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
		prompt := b.Build(mode, "Luna", nil, nil, "", nil)
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

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

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

	prompt := b.Build("discovery", "Luna", nil, us, "", nil)

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

// --- Story 3.1 Tests ---

func TestBuilder_SummarizePrompt_Loads(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.SummarizePrompt()
	if !strings.Contains(prompt, "Summarize") {
		t.Error("expected summarize prompt content")
	}
}

func TestBuilder_Build_WithNilUserState_UsesDefaults(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

	if !strings.Contains(prompt, "Engagement: unknown") {
		t.Error("expected unknown engagement level when userState is nil")
	}
	if !strings.Contains(prompt, "Gap: unknown") {
		t.Error("expected unknown gap when userState is nil")
	}
}

// --- Story 3.3 Tests ---

func TestBuilder_Build_WithProfile_InjectsFields(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	profile := &providers.ChatProfile{
		CoachName:        "Luna",
		Values:           []string{"authenticity", "growth"},
		Goals:            []string{"career change"},
		PersonalityTraits: []string{"analytical", "introverted"},
		DomainStates: map[string]providers.DomainState{
			"career": {Status: "transitioning", ConversationCount: 5},
		},
	}

	prompt := b.Build("discovery", "Luna", profile, nil, "", nil)

	if !strings.Contains(prompt, "Values: authenticity, growth") {
		t.Error("expected user values in prompt")
	}
	if !strings.Contains(prompt, "Goals: career change") {
		t.Error("expected user goals in prompt")
	}
	if !strings.Contains(prompt, "Traits: analytical, introverted") {
		t.Error("expected user traits in prompt")
	}
	if !strings.Contains(prompt, "career") {
		t.Error("expected domain states in prompt")
	}
}

func TestBuilder_Build_WithNilProfile_UsesNotYetKnown(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

	if !strings.Contains(prompt, "Values: not yet known") {
		t.Error("expected 'not yet known' for values when profile is nil")
	}
	if !strings.Contains(prompt, "Goals: not yet known") {
		t.Error("expected 'not yet known' for goals when profile is nil")
	}
	if !strings.Contains(prompt, "Traits: not yet known") {
		t.Error("expected 'not yet known' for traits when profile is nil")
	}
	if !strings.Contains(prompt, "Domains: not yet known") {
		t.Error("expected 'not yet known' for domains when profile is nil")
	}
}

func TestBuilder_Build_WithEmptyProfileFields_UsesNotYetKnown(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	profile := &providers.ChatProfile{
		CoachName: "Luna",
	}

	prompt := b.Build("discovery", "Luna", profile, nil, "", nil)

	if !strings.Contains(prompt, "Values: not yet known") {
		t.Error("expected 'not yet known' for empty values")
	}
	if !strings.Contains(prompt, "Goals: not yet known") {
		t.Error("expected 'not yet known' for empty goals")
	}
}

// --- Story 3.4 Tests ---

func TestBuilder_Build_WithRagContext_InjectsMemories(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	ragContext := "## Past Conversations\n**2026-03-20** — career\nSummary: Discussed career goals"
	prompt := b.Build("discovery", "Luna", nil, nil, ragContext, nil)

	if !strings.Contains(prompt, "Past Conversations") {
		t.Error("expected ragContext content in prompt")
	}
	if !strings.Contains(prompt, "Discussed career goals") {
		t.Error("expected ragContext summary in prompt")
	}
}

func TestBuilder_Build_WithEmptyRagContext_ReplacesCleanly(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

	if strings.Contains(prompt, "{{retrieved_memories}}") {
		t.Error("expected {{retrieved_memories}} template to be replaced")
	}
}

func TestBuilder_Build_WithNilRagContext_ReplacesCleanly(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	// Empty string simulates nil ragContext from handler
	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

	if strings.Contains(prompt, "{{retrieved_memories}}") {
		t.Error("expected template variable to be replaced even with empty string")
	}
}

// --- Story 5.1 Tests ---

func TestBuilder_Build_WithSprintContext_ActiveSprint(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	sc := &providers.SprintContext{
		ActiveSprint: &providers.ActiveSprintInfo{
			Name:           "Career Clarity Sprint",
			Status:         "active",
			StepsCompleted: 1,
			StepsTotal:     3,
			DayNumber:      3,
			TotalDays:      14,
		},
	}
	prompt := b.Build("discovery", "Luna", nil, nil, "", sc)

	if !strings.Contains(prompt, "Career Clarity Sprint") {
		t.Error("expected sprint name in prompt")
	}
	if !strings.Contains(prompt, "Day 3 of 14") {
		t.Error("expected day info in prompt")
	}
	if !strings.Contains(prompt, "1/3 steps complete") {
		t.Error("expected step progress in prompt")
	}
}

func TestBuilder_Build_WithSprintContext_PendingProposal(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	sc := &providers.SprintContext{
		PendingProposal: &providers.PendingProposal{
			Name: "Focus Sprint",
		},
	}
	prompt := b.Build("discovery", "Luna", nil, nil, "", sc)

	if !strings.Contains(prompt, "Focus Sprint") {
		t.Error("expected pending proposal name in prompt")
	}
	if !strings.Contains(prompt, "Re-surface this naturally") {
		t.Error("expected re-surface instruction in prompt")
	}
}

// --- Story 5.3 Tests ---

func TestSprintRetroPrompt_IncludesBasePersonaAndRetroSection(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	steps := []SprintRetroStep{
		{Description: "Research career options", CoachContext: "Exploring what fits"},
		{Description: "Update resume"},
		{Description: "Apply to 3 roles", CoachContext: "Building momentum"},
	}

	prompt := b.SprintRetroPrompt("Career Growth", 14, steps)

	// Must include base-persona
	if !strings.Contains(prompt, "You are") {
		t.Error("expected base-persona section in retro prompt")
	}
	// Must include sprint-retro section
	if !strings.Contains(prompt, "narrative retrospective") {
		t.Error("expected sprint-retro section in retro prompt")
	}
	// Must include sprint details
	if !strings.Contains(prompt, `Sprint: "Career Growth" (14 days)`) {
		t.Error("expected sprint name and duration in retro prompt")
	}
	// Must list step descriptions
	if !strings.Contains(prompt, "- Research career options (context: Exploring what fits)") {
		t.Error("expected step with coach context in retro prompt")
	}
	if !strings.Contains(prompt, "- Update resume\n") {
		t.Error("expected step without coach context in retro prompt")
	}
	if !strings.Contains(prompt, "- Apply to 3 roles (context: Building momentum)") {
		t.Error("expected third step with coach context in retro prompt")
	}
	// Must NOT include coaching sections
	if strings.Contains(prompt, "Discovery mode") {
		t.Error("retro prompt should not include discovery mode section")
	}
	if strings.Contains(prompt, "Mood selection") {
		t.Error("retro prompt should not include mood section")
	}
	if strings.Contains(prompt, "Challenger capability") {
		t.Error("retro prompt should not include challenger section")
	}
	if strings.Contains(prompt, "Safety classification") {
		t.Error("retro prompt should not include safety section")
	}
}

func TestSprintRetroPrompt_EmptySteps(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.SprintRetroPrompt("Test Sprint", 7, nil)

	if !strings.Contains(prompt, "Steps completed:") {
		t.Error("expected steps header even with no steps")
	}
	// Should not contain any step bullet points
	if strings.Contains(prompt, "- ") {
		t.Error("expected no step entries for empty steps list")
	}
}

func TestBuilder_Build_WithNilSprintContext_NoTemplate(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("discovery", "Luna", nil, nil, "", nil)

	if strings.Contains(prompt, "{{sprint_context}}") {
		t.Error("unreplaced sprint_context template variable found")
	}
}

// --- Story 5.4 Tests ---

func TestBuilder_Build_CheckInMode_IncludesCheckInSection(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("check_in", "Sage", nil, nil, "", nil)

	if !strings.Contains(prompt, "Check-in mode") {
		t.Error("expected check-in section in prompt")
	}
}

func TestBuilder_Build_CheckInMode_ExcludesDiscoveryAndDirective(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("check_in", "Sage", nil, nil, "", nil)

	if strings.Contains(prompt, "Discovery mode") {
		t.Error("check_in mode should not include Discovery mode section")
	}
	if strings.Contains(prompt, "Directive mode") {
		t.Error("check_in mode should not include Directive mode section")
	}
}

func TestBuilder_Build_CheckInMode_IncludesSharedSections(t *testing.T) {
	dir := setupTestSections(t)
	b, err := NewBuilder(dir)
	if err != nil {
		t.Fatalf("NewBuilder error: %v", err)
	}

	prompt := b.Build("check_in", "Sage", nil, nil, "", nil)
	for _, section := range []string{"Classify safety", "Select mood", "Tag domains", "Cultural context", "Mode transitions", "Challenger capability"} {
		if !strings.Contains(prompt, section) {
			t.Errorf("expected shared section %q in check_in prompt", section)
		}
	}
}
