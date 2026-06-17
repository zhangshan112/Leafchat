import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case encodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .httpError(_, message):
            if let message, !message.isEmpty {
                return message
            }
            return "Something went wrong. Please try again."
        case let .decodingFailed(error):
            return "Failed to decode response: \(error.localizedDescription)"
        case let .encodingFailed(error):
            return "Failed to encode request: \(error.localizedDescription)"
        }
    }
}
