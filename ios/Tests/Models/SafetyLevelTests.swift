import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SafetyLevel")
struct SafetyLevelTests {

    // MARK: - Comparable

    @Test("Green < Yellow < Orange < Red severity ordering")
    func test_comparable_ordering() {
        #expect(SafetyLevel.green < .yellow)
        #expect(SafetyLevel.yellow < .orange)
        #expect(SafetyLevel.orange < .red)
        #expect(SafetyLevel.green < .red)
        #expect(!(SafetyLevel.red < .green))
        #expect(!(SafetyLevel.yellow < .yellow))
    }

    @Test("Max picks most severe level")
    func test_max_picksMostSevere() {
        #expect(max(SafetyLevel.green, .yellow) == .yellow)
        #expect(max(SafetyLevel.orange, .red) == .red)
        #expect(max(SafetyLevel.green, .red) == .red)
    }

    // MARK: - Codable

    @Test("Codable roundtrip for all 4 values")
    func test_codable_roundtrip() throws {
        let levels: [SafetyLevel] = [.green, .yellow, .orange, .red]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for level in levels {
            let data = try encoder.encode(level)
            let decoded = try decoder.decode(SafetyLevel.self, from: data)
            #expect(decoded == level)
        }
    }

    @Test("Orange raw value is correct")
    func test_orange_rawValue() {
        #expect(SafetyLevel.orange.rawValue == "orange")
        #expect(SafetyLevel(rawValue: "orange") == .orange)
    }

    // MARK: - DatabaseValueConvertible

    @Test("DatabaseValueConvertible roundtrip for all 4 values")
    func test_databaseValue_roundtrip() {
        let levels: [SafetyLevel] = [.green, .yellow, .orange, .red]

        for level in levels {
            let dbValue = level.databaseValue
            let restored = SafetyLevel.fromDatabaseValue(dbValue)
            #expect(restored == level)
        }
    }

    @Test("Unknown raw value returns nil")
    func test_unknownRawValue_returnsNil() {
        #expect(SafetyLevel(rawValue: "unknown") == nil)
    }
}
