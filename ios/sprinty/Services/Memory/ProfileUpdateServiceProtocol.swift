import Foundation

protocol ProfileUpdateServiceProtocol: Sendable {
    func applyUpdate(_ update: ProfileUpdate, to profileId: UUID) async throws
}
