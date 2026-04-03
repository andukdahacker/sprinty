import Foundation
import Network
import Observation

enum ConnectionType: String, Sendable {
    case wifi
    case cellular
    case none
}

protocol ConnectivityMonitorProtocol: AnyObject, Sendable {
    @MainActor var isOnline: Bool { get }
    @MainActor var connectionType: ConnectionType { get }
}

@MainActor
@Observable
final class ConnectivityMonitor: ConnectivityMonitorProtocol, @unchecked Sendable {
    var isOnline: Bool = true
    var connectionType: ConnectionType = .wifi

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "connectivity")
    private weak var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let online = path.status == .satisfied
                self.isOnline = online
                self.appState?.isOnline = online
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else {
                    self.connectionType = .none
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
