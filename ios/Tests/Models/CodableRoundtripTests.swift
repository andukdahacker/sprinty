import Testing
import Foundation
@testable import sprinty

@Suite("Codable Roundtrip Tests")
struct CodableRoundtripTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("ConversationSession encodes and decodes correctly")
    func conversationSessionRoundtrip() throws {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1710000000),
            endedAt: Date(timeIntervalSince1970: 1710003600),
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "v1.0"
        )
        let data = try encoder.encode(session)
        let decoded = try decoder.decode(ConversationSession.self, from: data)
        #expect(decoded.id == session.id)
        #expect(decoded.type == session.type)
        #expect(decoded.mode == session.mode)
        #expect(decoded.safetyLevel == session.safetyLevel)
        #expect(decoded.promptVersion == session.promptVersion)
    }

    @Test("ConversationSession with nil optionals roundtrips")
    func conversationSessionNilOptionals() throws {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1710000000),
            endedAt: nil,
            type: .coaching,
            mode: .directive,
            safetyLevel: .yellow,
            promptVersion: nil
        )
        let data = try encoder.encode(session)
        let decoded = try decoder.decode(ConversationSession.self, from: data)
        #expect(decoded.endedAt == nil)
        #expect(decoded.promptVersion == nil)
        #expect(decoded.mode == .directive)
        #expect(decoded.safetyLevel == .yellow)
    }

    @Test("Message encodes and decodes correctly")
    func messageRoundtrip() throws {
        let message = Message(
            id: UUID(),
            sessionId: UUID(),
            role: .user,
            content: "Hello coach",
            timestamp: Date(timeIntervalSince1970: 1710000000)
        )
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)
        #expect(decoded.id == message.id)
        #expect(decoded.sessionId == message.sessionId)
        #expect(decoded.role == message.role)
        #expect(decoded.content == message.content)
    }

    @Test("All MessageRole cases encode to expected strings")
    func messageRoleEncoding() throws {
        for role in [MessageRole.user, .assistant, .system] {
            let data = try encoder.encode(role)
            let str = String(data: data, encoding: .utf8)
            #expect(str == "\"\(role.rawValue)\"")
        }
    }

    @Test("All SessionType cases encode to expected strings")
    func sessionTypeEncoding() throws {
        let data = try encoder.encode(SessionType.coaching)
        let str = String(data: data, encoding: .utf8)
        #expect(str == "\"coaching\"")
    }

    @Test("All CoachingMode cases encode to expected strings")
    func coachingModeEncoding() throws {
        for mode in [CoachingMode.discovery, .directive] {
            let data = try encoder.encode(mode)
            let str = String(data: data, encoding: .utf8)
            #expect(str == "\"\(mode.rawValue)\"")
        }
    }

    @Test("All SafetyLevel cases encode to expected strings")
    func safetyLevelEncoding() throws {
        for level in [SafetyLevel.green, .yellow, .red] {
            let data = try encoder.encode(level)
            let str = String(data: data, encoding: .utf8)
            #expect(str == "\"\(level.rawValue)\"")
        }
    }

    @Test("RegisterRequest encodes correctly")
    func registerRequestEncoding() throws {
        let req = RegisterRequest(deviceId: "test-uuid-123")
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["deviceId"] as? String == "test-uuid-123")
    }

    @Test("AuthResponse decodes correctly")
    func authResponseDecoding() throws {
        let json = #"{"token":"jwt-token-here"}"#
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(AuthResponse.self, from: data)
        #expect(response.token == "jwt-token-here")
    }
}
