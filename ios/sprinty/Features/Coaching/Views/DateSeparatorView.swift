import SwiftUI

struct DateSeparatorView: View {
    let date: Date
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Text(formattedDate)
            .dateSeparatorStyle()
            .foregroundStyle(theme.palette.dateSeparator)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Conversation from \(formattedDate)")
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
