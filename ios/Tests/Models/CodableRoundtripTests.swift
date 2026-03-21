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

    @Test("ConversationSession moodHistory encodes and decodes correctly")
    func test_conversationSession_moodHistory_encodesDecodes() throws {
        var session = ConversationSession(
            id: UUID(),
            startedAt: Date(timeIntervalSince1970: 1710000000),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        let moods = ["warm", "focused", "gentle"]
        session.moodHistory = String(data: try encoder.encode(moods), encoding: .utf8)

        let data = try encoder.encode(session)
        let decoded = try decoder.decode(ConversationSession.self, from: data)
        #expect(decoded.moodHistory != nil)

        let decodedMoods = try JSONDecoder().decode([String].self, from: Data(decoded.moodHistory!.utf8))
        #expect(decodedMoods == moods)
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

    @Test("AuthResponse decodes from shared fixture")
    func authResponseFromFixture() throws {
        let fixtureData = try Data(loadFixture("auth-register-response.json").utf8)
        let response = try decoder.decode(AuthResponse.self, from: fixtureData)
        #expect(response.token.isEmpty == false)
    }

    @Test("ChatRequest decodes from shared fixture")
    func chatRequestFromFixture() throws {
        let fixtureData = try Data(loadFixture("chat-request-sample.json").utf8)
        let json = try JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
        #expect(json?["messages"] != nil)
        #expect(json?["mode"] as? String == "discovery")
        #expect(json?["promptVersion"] as? String == "1.0")
    }

    @Test("Error response 401 decodes from shared fixture")
    func errorResponse401FromFixture() throws {
        let fixtureStr = try loadFixture("error-response-401.json")
        let json = try JSONSerialization.jsonObject(with: Data(fixtureStr.utf8)) as? [String: Any]
        #expect(json?["error"] as? String == "invalid_jwt")
        #expect(json?["message"] != nil)
    }

    @Test("Error response 502 decodes from shared fixture")
    func errorResponse502FromFixture() throws {
        let fixtureStr = try loadFixture("error-response-502.json")
        let json = try JSONSerialization.jsonObject(with: Data(fixtureStr.utf8)) as? [String: Any]
        #expect(json?["error"] as? String == "provider_unavailable")
        #expect(json?["message"] as? String == "Your coach needs a moment. Try again shortly.")
        #expect(json?["retryAfter"] as? Int == 10)
    }

    // MARK: - Story 3.3 — ChatProfile & UserProfile Expanded

    @Test("ChatProfile with full profile data roundtrips")
    func test_chatProfile_expanded_roundtrip() throws {
        let profile = ChatProfile(
            coachName: "Luna",
            values: ["authenticity", "growth"],
            goals: ["career transition", "better health"],
            personalityTraits: ["analytical", "introverted"],
            domainStates: [
                "career": DomainState(status: "transitioning", conversationCount: 5, lastUpdated: "2026-03-21T10:00:00Z"),
                "health": DomainState(status: nil, conversationCount: 2, lastUpdated: "2026-03-20T08:00:00Z")
            ]
        )

        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(ChatProfile.self, from: data)

        #expect(decoded.coachName == "Luna")
        #expect(decoded.values == ["authenticity", "growth"])
        #expect(decoded.goals == ["career transition", "better health"])
        #expect(decoded.personalityTraits == ["analytical", "introverted"])
        #expect(decoded.domainStates?["career"]?.conversationCount == 5)
        #expect(decoded.domainStates?["health"]?.conversationCount == 2)
    }

    @Test("ChatProfile with nil optionals roundtrips")
    func test_chatProfile_nilOptionals_roundtrip() throws {
        let profile = ChatProfile(
            coachName: "Luna",
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil
        )

        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(ChatProfile.self, from: data)

        #expect(decoded.coachName == "Luna")
        #expect(decoded.values == nil)
        #expect(decoded.goals == nil)
        #expect(decoded.personalityTraits == nil)
        #expect(decoded.domainStates == nil)
    }

    @Test("UserProfile encodes and decodes JSON fields correctly")
    func test_userProfile_jsonFields_roundtrip() throws {
        let values = ["authenticity", "growth"]
        let goals = ["career change"]
        let traits = ["analytical"]
        let states: [String: DomainState] = [
            "career": DomainState(status: "active", conversationCount: 3, lastUpdated: "2026-03-21")
        ]

        var profile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: "Luna",
            onboardingStep: 5,
            onboardingCompleted: true,
            values: UserProfile.encodeArray(values),
            goals: UserProfile.encodeArray(goals),
            personalityTraits: UserProfile.encodeArray(traits),
            domainStates: UserProfile.encodeDomainStates(states),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(profile.decodedValues == values)
        #expect(profile.decodedGoals == goals)
        #expect(profile.decodedPersonalityTraits == traits)
        #expect(profile.decodedDomainStates?["career"]?.conversationCount == 3)
    }

    @Test("UserProfile with nil JSON fields returns nil decoded values")
    func test_userProfile_nilJsonFields_returnsNil() throws {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: "Luna",
            onboardingStep: 5,
            onboardingCompleted: true,
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(profile.decodedValues == nil)
        #expect(profile.decodedGoals == nil)
        #expect(profile.decodedPersonalityTraits == nil)
        #expect(profile.decodedDomainStates == nil)
    }

    // MARK: - Story 3.4 — ChatRequest ragContext

    @Test("ChatRequest encodes ragContext when present")
    func test_chatRequest_withRagContext_encodes() throws {
        let request = ChatRequest(
            messages: [ChatRequestMessage(role: "user", content: "Hello")],
            mode: "discovery",
            promptVersion: "1.0",
            profile: nil,
            ragContext: "## Past Conversations\n**2026-03-20** — career\nSummary: Discussed career goals"
        )
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["ragContext"] as? String == "## Past Conversations\n**2026-03-20** — career\nSummary: Discussed career goals")
        #expect(json?["mode"] as? String == "discovery")
    }

    @Test("ChatRequest omits ragContext when nil")
    func test_chatRequest_withoutRagContext_omitsField() throws {
        let request = ChatRequest(
            messages: [ChatRequestMessage(role: "user", content: "Hello")],
            mode: "discovery",
            promptVersion: "1.0",
            profile: nil
        )
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["ragContext"] == nil)
        #expect(json?["messages"] != nil)
    }

    @Test("ChatRequest decodes ragContext from JSON")
    func test_chatRequest_decodesRagContext() throws {
        let jsonStr = """
        {
            "messages": [{"role": "user", "content": "Hi"}],
            "mode": "discovery",
            "promptVersion": "1.0",
            "ragContext": "Some past context"
        }
        """
        let decoded = try decoder.decode(ChatRequest.self, from: Data(jsonStr.utf8))
        #expect(decoded.ragContext == "Some past context")
    }

    @Test("ChatRequest decodes without ragContext field")
    func test_chatRequest_decodesWithoutRagContext() throws {
        let jsonStr = """
        {
            "messages": [{"role": "user", "content": "Hi"}],
            "mode": "discovery",
            "promptVersion": "1.0"
        }
        """
        let decoded = try decoder.decode(ChatRequest.self, from: Data(jsonStr.utf8))
        #expect(decoded.ragContext == nil)
    }

    // MARK: - Helpers

    private func loadFixture(_ filename: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixtureURL = testFile
            .deletingLastPathComponent() // Models/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("docs")
            .appendingPathComponent("fixtures")
            .appendingPathComponent(filename)
        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }
}
