import Foundation

protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(
        method: String,
        path: String,
        body: (any Encodable & Sendable)?,
        bearerToken: String?
    ) async throws -> T
}

extension APIClientProtocol {
    func request<T: Decodable & Sendable>(
        method: String,
        path: String,
        body: (any Encodable & Sendable)? = nil,
        bearerToken: String? = nil
    ) async throws -> T {
        try await request(method: method, path: path, body: body, bearerToken: bearerToken)
    }
}

final class APIClient: APIClientProtocol, Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func fromConfiguration(session: URLSession = .shared) throws -> APIClient {
        let urlString = Bundle.main.infoDictionary?["COACH_API_URL"] as? String ?? "http://localhost:8080"
        guard let url = URL(string: urlString) else {
            throw AppError.networkUnavailable
        }
        return APIClient(baseURL: url, session: session)
    }

    func request<T: Decodable & Sendable>(
        method: String,
        path: String,
        body: (any Encodable & Sendable)?,
        bearerToken: String?
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        if let bearerToken {
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AppError.authExpired
            }
            throw AppError.providerError(
                message: "HTTP \(httpResponse.statusCode)",
                retryAfter: nil
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
