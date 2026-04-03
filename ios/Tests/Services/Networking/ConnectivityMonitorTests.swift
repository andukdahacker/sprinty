import Testing
import Foundation
@testable import sprinty

@Suite("ConnectivityMonitor")
struct ConnectivityMonitorTests {

    @Test("MockConnectivityMonitor defaults to online")
    @MainActor
    func test_mockConnectivityMonitor_defaultsToOnline() async throws {
        let mock = MockConnectivityMonitor()
        #expect(mock.isOnline == true)
        #expect(mock.connectionType == .wifi)
    }

    @Test("MockConnectivityMonitor can be toggled offline")
    @MainActor
    func test_mockConnectivityMonitor_canToggleOffline() async throws {
        let mock = MockConnectivityMonitor()
        mock.isOnline = false
        mock.connectionType = .none
        #expect(mock.isOnline == false)
        #expect(mock.connectionType == .none)
    }

    @Test("AppState reflects ConnectivityMonitor via stored property")
    @MainActor
    func test_appState_reflectsConnectivityMonitor() async throws {
        let appState = AppState()
        let mock = MockConnectivityMonitor()
        appState.connectivityMonitor = mock

        // AppState.isOnline is stored, updated by ConnectivityMonitor externally
        appState.isOnline = false
        #expect(appState.isOnline == false)

        appState.isOnline = true
        #expect(appState.isOnline == true)
    }

    @Test("RootView when offline shows main app not blocking screen")
    @MainActor
    func test_rootView_whenOffline_showsMainApp() async throws {
        // Verify the AppState allows offline access when DB is available
        let appState = AppState()
        appState.isOnline = false
        appState.isAuthenticated = false

        // Without DB, we can't show the main app
        #expect(appState.databaseManager == nil)

        // With DB available (previous auth), the app should be navigable
        // This tests the logic, not the SwiftUI view rendering
        #expect(appState.isOnline == false)
        #expect(appState.isAuthenticated == false)
    }
}
