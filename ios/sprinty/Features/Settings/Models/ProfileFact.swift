import Foundation

struct ProfileFact: Identifiable, Sendable {
    let id: String          // e.g., "coachName", "values-0", "goals-1"
    let category: String    // "Coach Name", "Values", "Goals", "Personality", "Life Situation"
    let displayLabel: String // Natural language: "Your coach's name", "A value you hold"
    let value: String       // Current value in natural language
    var isEditing: Bool = false
}
