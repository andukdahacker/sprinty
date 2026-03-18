import Foundation
import GRDB

final class DatabaseManager: Sendable {
    let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    static func create() throws -> DatabaseManager {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            throw AppError.databaseError(
                underlying: NSError(
                    domain: "DatabaseManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "App Group container not available"]
                )
            )
        }

        let dbURL = containerURL.appendingPathComponent(Constants.databaseFilename)

        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: containerURL.path
        )

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            db.trace { /* structured logging placeholder */ _ in }
        }

        let dbPool = try DatabasePool(path: dbURL.path, configuration: configuration)

        try applyFileProtection(to: dbURL)

        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)

        return DatabaseManager(dbPool: dbPool)
    }

    private static func applyFileProtection(to url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}
