import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SettingsViewModel Export")
struct SettingsViewModelExportTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - checkHasConversations

    @Test @MainActor
    func test_checkHasConversations_withConversations_setsTrue() async throws {
        let mockExport = MockConversationExportService()
        mockExport.stubbedHasConversations = true
        let vm = SettingsViewModel(databaseManager: try makeTestDB(), exportService: mockExport)

        await vm.checkHasConversations()

        #expect(vm.hasConversations == true)
        #expect(mockExport.hasConversationsCallCount == 1)
    }

    @Test @MainActor
    func test_checkHasConversations_noConversations_setsFalse() async throws {
        let mockExport = MockConversationExportService()
        mockExport.stubbedHasConversations = false
        let vm = SettingsViewModel(databaseManager: try makeTestDB(), exportService: mockExport)

        await vm.checkHasConversations()

        #expect(vm.hasConversations == false)
    }

    @Test @MainActor
    func test_checkHasConversations_noService_remainsFalse() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())

        await vm.checkHasConversations()

        #expect(vm.hasConversations == false)
    }

    // MARK: - exportConversations

    @Test @MainActor
    func test_exportConversations_success_setsFileURL() async throws {
        let mockExport = MockConversationExportService()
        let expectedURL = URL(fileURLWithPath: "/tmp/test-export.md")
        mockExport.stubbedExportURL = expectedURL
        let vm = SettingsViewModel(databaseManager: try makeTestDB(), exportService: mockExport)

        await vm.exportConversations()

        #expect(vm.exportFileURL == expectedURL)
        #expect(vm.isExporting == false)
        #expect(vm.exportError == nil)
        #expect(mockExport.exportCallCount == 1)
    }

    @Test @MainActor
    func test_exportConversations_failure_setsError() async throws {
        let mockExport = MockConversationExportService()
        mockExport.stubbedError = NSError(domain: "test", code: 1)
        let vm = SettingsViewModel(databaseManager: try makeTestDB(), exportService: mockExport)

        await vm.exportConversations()

        #expect(vm.exportFileURL == nil)
        #expect(vm.isExporting == false)
        #expect(vm.exportError != nil)
    }

    @Test @MainActor
    func test_exportConversations_noService_doesNothing() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())

        await vm.exportConversations()

        #expect(vm.exportFileURL == nil)
        #expect(vm.isExporting == false)
        #expect(vm.exportError == nil)
    }

    // MARK: - dismissExportSuccess

    @Test @MainActor
    func test_dismissExportSuccess_clearsMessage() async throws {
        let vm = SettingsViewModel(databaseManager: try makeTestDB())
        vm.exportSuccessMessage = "Your conversation belongs to you"

        vm.dismissExportSuccess()

        #expect(vm.exportSuccessMessage == nil)
    }
}
