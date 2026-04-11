import Testing
import Foundation
@testable import sprinty

@Suite("Privacy Manifest")
struct PrivacyManifestTests {

    private func loadManifest() throws -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
            Issue.record("PrivacyInfo.xcprivacy not found in main bundle — verify it is in Copy Bundle Resources")
            throw CocoaError(.fileReadNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            Issue.record("PrivacyInfo.xcprivacy is not a valid plist dictionary")
            throw CocoaError(.propertyListReadCorrupt)
        }
        return plist
    }

    @Test
    func test_manifest_loadsFromMainBundle() throws {
        let plist = try loadManifest()
        #expect(plist.isEmpty == false)
    }

    @Test
    func test_manifest_NSPrivacyTracking_isFalse() throws {
        let plist = try loadManifest()
        let tracking = plist["NSPrivacyTracking"] as? Bool
        #expect(tracking == false)
    }

    @Test
    func test_manifest_NSPrivacyTrackingDomains_isEmpty() throws {
        let plist = try loadManifest()
        let domains = plist["NSPrivacyTrackingDomains"] as? [String]
        #expect(domains?.isEmpty == true)
    }

    @Test
    func test_manifest_NSPrivacyCollectedDataTypes_isEmpty() throws {
        let plist = try loadManifest()
        let dataTypes = plist["NSPrivacyCollectedDataTypes"] as? [Any]
        #expect(dataTypes?.isEmpty == true)
    }

    @Test
    func test_manifest_declaresUserDefaultsRequiredReason_CA92_1() throws {
        let plist = try loadManifest()
        let apiTypes = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        #expect(apiTypes != nil)

        let userDefaultsEntry = apiTypes?.first { entry in
            (entry["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        #expect(userDefaultsEntry != nil, "Manifest must declare NSPrivacyAccessedAPICategoryUserDefaults")

        let reasons = userDefaultsEntry?["NSPrivacyAccessedAPIReasons"] as? [String]
        #expect(reasons?.contains("CA92.1") == true, "UserDefaults reason must include CA92.1")
    }
}
