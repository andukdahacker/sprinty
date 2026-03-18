import Foundation

struct SSEParser: Sendable {
    func parse(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var currentEventType: String?
                var currentData: String?

                do {
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }

                        if line.hasPrefix("event: ") {
                            currentEventType = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: ") {
                            currentData = String(line.dropFirst(6))
                        } else if line.isEmpty {
                            if let eventType = currentEventType, let data = currentData {
                                let event = SSEEvent(type: eventType, data: data)
                                continuation.yield(event)
                            }
                            currentEventType = nil
                            currentData = nil
                        }
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

struct SSEEvent: Sendable {
    let type: String
    let data: String
}
