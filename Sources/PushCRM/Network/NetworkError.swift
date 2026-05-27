import Foundation

/// Typed network errors for the SDK networking layer
public enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case encodingFailed(String)
    case decodingFailed(String)
    case httpError(statusCode: Int, data: Data?)
    case timeout
    case noConnection
    case cancelled
    case retriesExhausted(lastError: String)
    case unknown(String)

    public var isRetryable: Bool {
        switch self {
        case .httpError(let code, _): return code >= 500 || code == 429
        case .timeout, .noConnection: return true
        default: return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .encodingFailed(let msg): return "Encoding failed: \(msg)"
        case .decodingFailed(let msg): return "Decoding failed: \(msg)"
        case .httpError(let code, _): return "HTTP error \(code)"
        case .timeout: return "Request timed out"
        case .noConnection: return "No network connection"
        case .cancelled: return "Request cancelled"
        case .retriesExhausted(let msg): return "Retries exhausted: \(msg)"
        case .unknown(let msg): return msg
        }
    }

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
