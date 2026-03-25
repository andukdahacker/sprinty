package prompts

import (
	"crypto/sha256"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/ducdo/sprinty/server/providers"
)

// Builder assembles system prompts from modular section files.
type Builder struct {
	sections     map[string]string // section name -> content
	contentHash  string            // SHA-256 of all section contents
	sectionsPath string
}

// NewBuilder reads all section files from the given directory and computes a content hash.
func NewBuilder(sectionsPath string) (*Builder, error) {
	b := &Builder{
		sections:     make(map[string]string),
		sectionsPath: sectionsPath,
	}

	sectionFiles := []string{
		"base-persona.md",
		"mode-discovery.md",
		"mode-directive.md",
		"safety.md",
		"mood.md",
		"tagging.md",
		"cultural.md",
		"context-injection.md",
		"mode-transitions.md",
		"challenger.md",
		"summarize.md",
		"sprint-retro.md",
	}

	var allContent strings.Builder

	for _, filename := range sectionFiles {
		path := filepath.Join(sectionsPath, filename)
		data, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("prompts.NewBuilder: failed to read %s: %w", filename, err)
		}
		name := strings.TrimSuffix(filename, ".md")
		content := string(data)
		b.sections[name] = content
		allContent.WriteString(content)
	}

	hash := sha256.Sum256([]byte(allContent.String()))
	b.contentHash = fmt.Sprintf("%x", hash[:8]) // first 8 bytes = 16 hex chars

	slog.Info("prompt builder initialized", "hash", b.contentHash, "sections", len(b.sections))

	return b, nil
}

// ContentHash returns the version hash of all prompt sections.
func (b *Builder) ContentHash() string {
	return b.contentHash
}

// SummarizePrompt returns the summarization system prompt.
func (b *Builder) SummarizePrompt() string {
	if s, ok := b.sections["summarize"]; ok {
		return s
	}
	return ""
}

// SprintRetroStep holds a single step's info for retro prompt assembly.
type SprintRetroStep struct {
	Description  string `json:"description"`
	CoachContext string `json:"coachContext,omitempty"`
}

// SprintRetroPrompt assembles a standalone prompt for sprint retrospective generation.
func (b *Builder) SprintRetroPrompt(sprintName string, durationDays int, steps []SprintRetroStep) string {
	var prompt strings.Builder
	prompt.WriteString(b.sections["base-persona"])
	prompt.WriteString("\n\n")
	prompt.WriteString(b.sections["sprint-retro"])
	prompt.WriteString("\n\n## Sprint Details\n")
	prompt.WriteString(fmt.Sprintf("Sprint: \"%s\" (%d days)\n\nSteps completed:\n", sprintName, durationDays))
	for _, s := range steps {
		prompt.WriteString(fmt.Sprintf("- %s", s.Description))
		if s.CoachContext != "" {
			prompt.WriteString(fmt.Sprintf(" (context: %s)", s.CoachContext))
		}
		prompt.WriteString("\n")
	}
	return prompt.String()
}

// Build assembles a system prompt for the given mode, coach name, profile, and user state.
func (b *Builder) Build(mode string, coachName string, profile *providers.ChatProfile, userState *providers.UserState, ragContext string, sprintContext *providers.SprintContext) string {
	var prompt strings.Builder

	// Always include base persona
	prompt.WriteString(b.sections["base-persona"])
	prompt.WriteString("\n\n")

	// Mode-specific section
	switch mode {
	case "discovery":
		if s, ok := b.sections["mode-discovery"]; ok {
			prompt.WriteString(s)
			prompt.WriteString("\n\n")
		}
	case "directive":
		if s, ok := b.sections["mode-directive"]; ok {
			prompt.WriteString(s)
			prompt.WriteString("\n\n")
		}
	default:
		// Default to discovery mode
		if s, ok := b.sections["mode-discovery"]; ok {
			prompt.WriteString(s)
			prompt.WriteString("\n\n")
		}
	}

	// Always include safety, mood, tagging, cultural
	for _, section := range []string{"safety", "mood", "tagging", "cultural", "mode-transitions", "challenger"} {
		if s, ok := b.sections[section]; ok {
			prompt.WriteString(s)
			prompt.WriteString("\n\n")
		}
	}

	// Context injection (always last)
	if s, ok := b.sections["context-injection"]; ok {
		prompt.WriteString(s)
	}

	// Replace template slots
	result := prompt.String()
	if coachName != "" {
		result = strings.ReplaceAll(result, "{{coach_name}}", coachName)
	} else {
		result = strings.ReplaceAll(result, "{{coach_name}}", "Coach")
	}

	// Replace profile template variables
	if profile != nil {
		if len(profile.Values) > 0 {
			result = strings.ReplaceAll(result, "{{user_values}}", strings.Join(profile.Values, ", "))
		} else {
			result = strings.ReplaceAll(result, "{{user_values}}", "not yet known")
		}
		if len(profile.Goals) > 0 {
			result = strings.ReplaceAll(result, "{{user_goals}}", strings.Join(profile.Goals, ", "))
		} else {
			result = strings.ReplaceAll(result, "{{user_goals}}", "not yet known")
		}
		if len(profile.PersonalityTraits) > 0 {
			result = strings.ReplaceAll(result, "{{user_traits}}", strings.Join(profile.PersonalityTraits, ", "))
		} else {
			result = strings.ReplaceAll(result, "{{user_traits}}", "not yet known")
		}
		if len(profile.DomainStates) > 0 {
			var parts []string
			for domain, state := range profile.DomainStates {
				part := domain
				if state.Status != "" {
					part += " (" + state.Status + ")"
				}
				if state.ConversationCount > 0 {
					part += fmt.Sprintf(" [%d conversations]", state.ConversationCount)
				}
				parts = append(parts, part)
			}
			result = strings.ReplaceAll(result, "{{domain_states}}", strings.Join(parts, "; "))
		} else {
			result = strings.ReplaceAll(result, "{{domain_states}}", "not yet known")
		}
	} else {
		result = strings.ReplaceAll(result, "{{user_values}}", "not yet known")
		result = strings.ReplaceAll(result, "{{user_goals}}", "not yet known")
		result = strings.ReplaceAll(result, "{{user_traits}}", "not yet known")
		result = strings.ReplaceAll(result, "{{domain_states}}", "not yet known")
	}

	// Replace user state template variables
	if userState != nil {
		result = strings.ReplaceAll(result, "{{engagement_level}}", userState.EngagementLevel)
		result = strings.ReplaceAll(result, "{{recent_moods}}", strings.Join(userState.RecentMoods, ", "))
		result = strings.ReplaceAll(result, "{{avg_message_length}}", userState.AvgMessageLength)
		result = strings.ReplaceAll(result, "{{session_count}}", strconv.Itoa(userState.SessionCount))
		if userState.LastSessionGapHours != nil {
			result = strings.ReplaceAll(result, "{{last_session_gap}}", strconv.Itoa(*userState.LastSessionGapHours)+"h")
		} else {
			result = strings.ReplaceAll(result, "{{last_session_gap}}", "unknown")
		}
		result = strings.ReplaceAll(result, "{{recent_session_intensity}}", userState.RecentSessionIntensity)
	} else {
		result = strings.ReplaceAll(result, "{{engagement_level}}", "unknown")
		result = strings.ReplaceAll(result, "{{recent_moods}}", "unknown")
		result = strings.ReplaceAll(result, "{{avg_message_length}}", "unknown")
		result = strings.ReplaceAll(result, "{{session_count}}", "unknown")
		result = strings.ReplaceAll(result, "{{last_session_gap}}", "unknown")
		result = strings.ReplaceAll(result, "{{recent_session_intensity}}", "unknown")
	}

	// Replace RAG context
	result = strings.ReplaceAll(result, "{{retrieved_memories}}", ragContext)

	// Replace sprint context
	if sprintContext != nil {
		var sprintText strings.Builder
		if sprintContext.ActiveSprint != nil {
			s := sprintContext.ActiveSprint
			sprintText.WriteString(fmt.Sprintf("## Current Sprint Context\nSprint: \"%s\" (Day %d of %d)\n", s.Name, s.DayNumber, s.TotalDays))
			sprintText.WriteString(fmt.Sprintf("Progress: %d/%d steps complete\nStatus: %s\n", s.StepsCompleted, s.StepsTotal, s.Status))

			if s.LastStepCompletedAt != nil {
				sprintText.WriteString("IMPORTANT: User recently completed a sprint step. This is a celebration moment. Do NOT activate Challenger mode in this session (UX-DR78 transition rhythm).\n")
			}
			if s.SprintJustCompleted != nil && *s.SprintJustCompleted {
				sprintText.WriteString("IMPORTANT: User just completed their entire sprint! This is a major milestone. Acknowledge their achievement warmly. No Challenger this session.\n")
			}
		}
		if sprintContext.PendingProposal != nil {
			p := sprintContext.PendingProposal
			sprintText.WriteString(fmt.Sprintf("\n## Pending Sprint Proposal (from previous conversation)\nThe user was offered but didn't confirm: \"%s\". Re-surface this naturally.\n", p.Name))
		}
		result = strings.ReplaceAll(result, "{{sprint_context}}", sprintText.String())
	} else {
		result = strings.ReplaceAll(result, "{{sprint_context}}", "")
	}

	return result
}
