import Foundation

struct APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder.apiDecoder
        self.encoder = JSONEncoder.apiEncoder
    }

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        as type: T.Type = T.self,
        bearerToken: String? = nil
    ) async throws -> T {
        let request = try makeRequest(for: endpoint, bearerToken: bearerToken)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func requestVoid(_ endpoint: APIEndpoint, bearerToken: String? = nil) async throws {
        _ = try await request(endpoint, as: EmptyResponse.self, bearerToken: bearerToken)
    }

    private func makeRequest(for endpoint: APIEndpoint, bearerToken: String?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        components.queryItems = endpoint.queryItems

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: APIConfig.defaultTimeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = try encodeBody(for: endpoint) {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func encodeBody(for endpoint: APIEndpoint) throws -> Data? {
        do {
            switch endpoint {
            case let .authRegister(payload):
                return try encoder.encode(payload)
            case let .authLogin(payload):
                return try encoder.encode(payload)
            case let .authApple(payload):
                return try encoder.encode(payload)
            case let .createPlant(payload):
                return try encoder.encode(payload)
            case let .registerPushToken(payload):
                return try encoder.encode(payload)
            case let .authUpdateProfile(payload):
                return try encoder.encode(payload)
            case let .syncUserEntitlements(payload):
                return try encoder.encode(payload)
            case .health, .authMe, .authLogout, .authDeleteAccount, .plants, .userEntitlements:
                return nil
            }
        } catch {
            throw NetworkError.encodingFailed(error)
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard let payload = try? decoder.decode(APIErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }
        return payload.error ?? payload.message
    }
}

private struct EmptyResponse: Decodable {}

private extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.fractional.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter.standard.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        return decoder
    }
}

private extension JSONEncoder {
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }
}

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
