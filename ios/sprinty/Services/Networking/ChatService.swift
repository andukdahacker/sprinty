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

    func streamChat(messages: [ChatRequestMessage], mode: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let token = try authService.getToken()
                    let chatRequest = ChatRequest(messages: messages, mode: mode, promptVersion: "1.0")

                    let url = baseURL.appendingPathComponent("v1/chat")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(chatRequest)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AppError.networkUnavailable
                    }

                    if httpResponse.statusCode == 401 {
                        throw AppError.authExpired
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw AppError.providerError(
                            message: "Your coach needs a moment. Try again shortly.",
                            retryAfter: nil
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
}
