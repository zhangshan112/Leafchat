import Foundation
import OSLog

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
        logRequest(request)

        let startedAt = Date()
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logTransportError(error, request: request, startedAt: startedAt)
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logInvalidResponse(response, data: data, request: request, startedAt: startedAt)
            throw NetworkError.invalidResponse
        }

        logResponse(httpResponse, data: data, request: request, startedAt: startedAt)

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

    private func logRequest(_ request: URLRequest) {
        guard APIConfig.isNetworkLoggingEnabled else { return }

        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<invalid-url>"
        let headers = formatHeaders(request.allHTTPHeaderFields)
        let body = formatBody(request.httpBody)

        Self.logger.debug(
            """

            API Request
            Method: \(method, privacy: .public)
            URL: \(url, privacy: .public)
            Headers: \(headers, privacy: .public)
            Body: \(body, privacy: .public)
            """
        )
    }

    private func logResponse(
        _ response: HTTPURLResponse,
        data: Data,
        request: URLRequest,
        startedAt: Date
    ) {
        guard APIConfig.isNetworkLoggingEnabled else { return }

        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<invalid-url>"
        let duration = String(format: "%.0fms", Date().timeIntervalSince(startedAt) * 1000)
        let headers = formatHeaders(response.allHeaderFields)
        let body = formatBody(data)

        Self.logger.debug(
            """

            API Response
            Method: \(method, privacy: .public)
            URL: \(url, privacy: .public)
            Status: \(response.statusCode, privacy: .public)
            Duration: \(duration, privacy: .public)
            Headers: \(headers, privacy: .public)
            Body: \(body, privacy: .public)
            """
        )
    }

    private func logTransportError(
        _ error: Error,
        request: URLRequest,
        startedAt: Date
    ) {
        guard APIConfig.isNetworkLoggingEnabled else { return }

        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<invalid-url>"
        let duration = String(format: "%.0fms", Date().timeIntervalSince(startedAt) * 1000)

        Self.logger.error(
            """

            API Transport Error
            Method: \(method, privacy: .public)
            URL: \(url, privacy: .public)
            Duration: \(duration, privacy: .public)
            Error: \(error.localizedDescription, privacy: .public)
            """
        )
    }

    private func logInvalidResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        startedAt: Date
    ) {
        guard APIConfig.isNetworkLoggingEnabled else { return }

        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<invalid-url>"
        let duration = String(format: "%.0fms", Date().timeIntervalSince(startedAt) * 1000)
        let body = formatBody(data)

        Self.logger.error(
            """

            API Invalid Response
            Method: \(method, privacy: .public)
            URL: \(url, privacy: .public)
            Duration: \(duration, privacy: .public)
            Response: \(String(describing: response), privacy: .public)
            Body: \(body, privacy: .public)
            """
        )
    }

    private func formatHeaders(_ headers: [String: String]?) -> String {
        guard let headers, !headers.isEmpty else {
            return "{}"
        }

        let sanitized = headers.reduce(into: [String: String]()) { result, item in
            let key = item.key
            let value = item.value
            result[key] = shouldRedact(key) ? "<redacted>" : value
        }

        return prettyJSONString(from: sanitized) ?? String(describing: sanitized)
    }

    private func formatHeaders(_ headers: [AnyHashable: Any]) -> String {
        guard !headers.isEmpty else {
            return "{}"
        }

        let sanitized = headers.reduce(into: [String: String]()) { result, item in
            let key = String(describing: item.key)
            let value = String(describing: item.value)
            result[key] = shouldRedact(key) ? "<redacted>" : value
        }

        return prettyJSONString(from: sanitized) ?? String(describing: sanitized)
    }

    private func formatBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else {
            return "{}"
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
        }

        let sanitized = redactSensitiveValues(in: json)

        return prettyJSONString(from: sanitized) ?? String(describing: sanitized)
    }

    private func redactSensitiveValues(in value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, item in
                result[item.key] = shouldRedact(item.key)
                    ? "<redacted>"
                    : redactSensitiveValues(in: item.value)
            }
        }

        if let array = value as? [Any] {
            return array.map { redactSensitiveValues(in: $0) }
        }

        return value
    }

    private func shouldRedact(_ key: String) -> Bool {
        let lowercased = key.lowercased()

        return lowercased.contains("authorization") ||
            lowercased.contains("password") ||
            lowercased.contains("token") ||
            lowercased.contains("secret")
    }

    private func prettyJSONString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? AppBranding.name,
        category: "APIClient"
    )
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
