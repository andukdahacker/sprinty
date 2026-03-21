import Foundation

final class ChatService: ChatServiceProtocol, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let authService: AuthServiceProtocol

    init(baseURL: URL, authService: AuthServiceProtocol, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authService = authService
        self.session = session
    }

    static func fromConfiguration(authService: AuthServiceProtocol, session: URLSession = .shared) throws -> ChatService {
        let urlString = Bundle.main.infoDictionary?["COACH_API_URL"] as? String ?? "http://localhost:8080"
        guard let url = URL(string: urlString) else {
            throw AppError.networkUnavailable
        }
        return ChatService(baseURL: url, authService: authService, session: session)
    }

    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState? = nil, ragContext: String? = nil) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let token = try authService.getToken()
                    let chatRequest = ChatRequest(messages: messages, mode: mode, promptVersion: "1.0", profile: profile, userState: userState, ragContext: ragContext)

                    let url = baseURL.appendingPathComponent("v1/chat")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                    let jsonData = try JSONEncoder().encode(chatRequest)

                    // Compress request body with deflate
                    if let compressed = try? (jsonData as NSData).compressed(using: .zlib) as Data {
                        request.httpBody = compressed
                        request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
                    } else {
                        request.httpBody = jsonData
                    }

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AppError.networkUnavailable
                    }

                    if httpResponse.statusCode == 401 {
                        throw AppError.authExpired
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Parse retryAfter from error response JSON body
                        let retryAfter = await Self.parseRetryAfter(from: bytes)
                        throw AppError.providerError(
                            message: "Your coach needs a moment. Try again shortly.",
                            retryAfter: retryAfter
                        )
                    }

                    let parser = SSEParser()
                    let sseStream = parser.parse(bytes: bytes)

                    for try await sseEvent in sseStream {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)
                        continuation.yield(chatEvent)
                    }

                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse {
        let token = try authService.getToken()
        let chatRequest = ChatRequest(messages: messages, mode: "summarize", promptVersion: "1.0", profile: nil)

        let url = baseURL.appendingPathComponent("v1/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let jsonData = try JSONEncoder().encode(chatRequest)

        if let compressed = try? (jsonData as NSData).compressed(using: .zlib) as Data {
            request.httpBody = compressed
            request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
        } else {
            request.httpBody = jsonData
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }

        if httpResponse.statusCode == 401 {
            throw AppError.authExpired
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError.providerError(
                message: "Summary generation failed.",
                retryAfter: nil
            )
        }

        return try JSONDecoder().decode(SummaryResponse.self, from: data)
    }

    private static func parseRetryAfter(from bytes: URLSession.AsyncBytes) async -> Int? {
        // Collect error response body and parse retryAfter from JSON
        do {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                // Cap at 4KB to avoid reading a huge body on unexpected responses
                if data.count > 4096 { break }
            }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let retryAfter = json["retryAfter"] as? Int {
                return retryAfter
            }
        } catch {
            // Failed to read/parse body — fall through to nil
        }
        return nil
    }
}
