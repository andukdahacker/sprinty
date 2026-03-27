import SwiftUI

enum ContactMethod: String, Sendable {
    case phone
    case text
    case url
}

struct ProfessionalResource: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let description: String
    let contactMethod: ContactMethod
    let value: String

    static let crisisResources: [ProfessionalResource] = [
        ProfessionalResource(
            name: "988 Suicide & Crisis Lifeline",
            description: "Free, confidential support available 24/7",
            contactMethod: .phone,
            value: "988"
        ),
        ProfessionalResource(
            name: "Crisis Text Line",
            description: "Text HOME to connect with a trained crisis counselor",
            contactMethod: .text,
            value: "741741"
        ),
        ProfessionalResource(
            name: "Find a Therapist",
            description: "Search for licensed therapists in your area",
            contactMethod: .url,
            value: "https://www.psychologytoday.com/us/therapists"
        ),
    ]
}

struct ProfessionalResourcesView: View {
    let isProminent: Bool
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.dialogueTurn) {
            Text("You're not alone")
                .font(isProminent ? .title3.weight(.semibold) : .headline)
                .foregroundStyle(theme.palette.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("These resources are here for you, anytime.")
                .font(.subheadline)
                .foregroundStyle(theme.palette.textSecondary)

            ForEach(ProfessionalResource.crisisResources) { resource in
                resourceRow(resource)
            }
        }
        .padding(theme.spacing.dialogueTurn)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius.container)
                .fill(theme.palette.insightBackground.opacity(0.9))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Professional support resources")
    }

    @ViewBuilder
    private func resourceRow(_ resource: ProfessionalResource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(resource.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.palette.textPrimary)

            Text(resource.description)
                .font(.caption)
                .foregroundStyle(theme.palette.textSecondary)

            contactButton(for: resource)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func contactButton(for resource: ProfessionalResource) -> some View {
        switch resource.contactMethod {
        case .phone:
            if let url = URL(string: "tel:\(resource.value)") {
                Link(destination: url) {
                    Label("Call \(resource.value)", systemImage: "phone.fill")
                        .font(.subheadline.weight(.medium))
                }
                .accessibilityHint("Opens phone to call \(resource.name)")
            }
        case .text:
            if let url = URL(string: "sms:\(resource.value)") {
                Link(destination: url) {
                    Label("Text HOME to \(resource.value)", systemImage: "message.fill")
                        .font(.subheadline.weight(.medium))
                }
                .accessibilityHint("Opens messages to text \(resource.name)")
            }
        case .url:
            if let url = URL(string: resource.value) {
                Link(destination: url) {
                    Label("Find help nearby", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.medium))
                }
                .accessibilityHint("Opens browser to \(resource.name)")
            }
        }
    }
}
