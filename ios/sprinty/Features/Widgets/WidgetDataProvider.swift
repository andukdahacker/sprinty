import Foundation
import GRDB

struct SprintyWidgetEntry: Sendable {
    let date: Date
    let avatarId: String
    let avatarState: AvatarState
    let hasActiveSprint: Bool
    let sprintName: String
    let sprintProgress: Double
    let currentStep: Int
    let totalSteps: Int
    let nextActionTitle: String?
    let dayNumber: Int
    let totalDays: Int
    let isPaused: Bool

    static let placeholder = SprintyWidgetEntry(
        date: Date(),
        avatarId: "avatar_classic",
        avatarState: .active,
        hasActiveSprint: false,
        sprintName: "",
        sprintProgress: 0.0,
        currentStep: 0,
        totalSteps: 0,
        nextActionTitle: nil,
        dayNumber: 0,
        totalDays: 0,
        isPaused: false
    )
}

struct WidgetDataProvider: Sendable {
    static func openReadOnlyDatabase() throws -> DatabasePool {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            throw AppError.databaseError(
                underlying: NSError(
                    domain: "WidgetDataProvider",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "App Group container not available"]
                )
            )
        }

        let dbURL = containerURL.appendingPathComponent(Constants.databaseFilename)

        var configuration = Configuration()
        configuration.readonly = true

        return try DatabasePool(path: dbURL.path, configuration: configuration)
    }

    static func fetchWidgetData(db: Database) throws -> SprintyWidgetEntry {
        let profile = try UserProfile.current().fetchOne(db)
        let avatarId = profile?.avatarId ?? "avatar_classic"
        let isPaused = profile?.isPaused ?? false
        let avatarState = AvatarState.derive(isPaused: isPaused)

        guard let sprint = try Sprint.active().fetchOne(db) else {
            return SprintyWidgetEntry(
                date: Date(),
                avatarId: avatarId,
                avatarState: avatarState,
                hasActiveSprint: false,
                sprintName: "",
                sprintProgress: 0.0,
                currentStep: 0,
                totalSteps: 0,
                nextActionTitle: nil,
                dayNumber: 0,
                totalDays: 0,
                isPaused: isPaused
            )
        }

        let steps = try SprintStep.forSprint(id: sprint.id).fetchAll(db)
        let completedCount = steps.filter(\.completed).count
        let totalCount = steps.count
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0

        let dayNumber = (Calendar.current.dateComponents([.day], from: sprint.startDate, to: Date()).day ?? 0) + 1
        let totalDays = (Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0) + 1

        let nextActionTitle = steps.first(where: { !$0.completed })?.description

        return SprintyWidgetEntry(
            date: Date(),
            avatarId: avatarId,
            avatarState: avatarState,
            hasActiveSprint: true,
            sprintName: sprint.name,
            sprintProgress: progress,
            currentStep: completedCount,
            totalSteps: totalCount,
            nextActionTitle: nextActionTitle,
            dayNumber: dayNumber,
            totalDays: totalDays,
            isPaused: isPaused
        )
    }
}
