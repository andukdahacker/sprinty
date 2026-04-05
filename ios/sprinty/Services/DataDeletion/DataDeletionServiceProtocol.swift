import Foundation

protocol DataDeletionServiceProtocol: Sendable {
    func deleteAllData() async throws
}
