import Testing
import Foundation
@testable import sprinty

@Suite("ModeSegment")
struct ModeSegmentTests {

    @Test("Segments accumulate on mode changes")
    func test_modeSegments_accumulateOnChanges() throws {
        var segments: [ModeSegment] = [ModeSegment(mode: .discovery, messageIndex: 0)]
        segments.append(ModeSegment(mode: .directive, messageIndex: 3))
        segments.append(ModeSegment(mode: .discovery, messageIndex: 7))

        #expect(segments.count == 3)
        #expect(segments[0].mode == .discovery)
        #expect(segments[0].messageIndex == 0)
        #expect(segments[1].mode == .directive)
        #expect(segments[1].messageIndex == 3)
        #expect(segments[2].mode == .discovery)
        #expect(segments[2].messageIndex == 7)
    }

    @Test("Initial segment uses session's actual mode")
    func test_modeSegments_initialSegmentUsesSessionMode() throws {
        let discoverySegments = [ModeSegment(mode: .discovery, messageIndex: 0)]
        #expect(discoverySegments[0].mode == .discovery)

        let directiveSegments = [ModeSegment(mode: .directive, messageIndex: 0)]
        #expect(directiveSegments[0].mode == .directive)
    }

    @Test("JSON roundtrip encoding preserves all fields")
    func test_modeSegments_jsonRoundtrip() throws {
        let segments = [
            ModeSegment(mode: .discovery, messageIndex: 0),
            ModeSegment(mode: .directive, messageIndex: 5),
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(segments)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ModeSegment].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].mode == .discovery)
        #expect(decoded[0].messageIndex == 0)
        #expect(decoded[1].mode == .directive)
        #expect(decoded[1].messageIndex == 5)
    }

    @Test("ModeSegment JSON matches expected format")
    func test_modeSegment_jsonFormat() throws {
        let segment = ModeSegment(mode: .directive, messageIndex: 3)
        let data = try JSONEncoder().encode(segment)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["mode"] as? String == "directive")
        #expect(json?["messageIndex"] as? Int == 3)
    }
}
