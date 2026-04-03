@testable import sprinty
import Foundation

final class MockConnectivityMonitor: ConnectivityMonitorProtocol, @unchecked Sendable {
    @MainActor var isOnline: Bool = true
    @MainActor var connectionType: ConnectionType = .wifi
}
