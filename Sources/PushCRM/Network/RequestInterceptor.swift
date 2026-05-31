import Foundation

/// Protocol for intercepting requests before sending and responses after receiving
public protocol RequestInterceptor: Sendable {
    func intercept(request: URLRequest) async throws -> URLRequest
    func intercept(response: Data, httpResponse: HTTPURLResponse) async throws -> Data
}

/// Default implementation — passthrough
public extension RequestInterceptor {
    func intercept(response: Data, httpResponse: HTTPURLResponse) async throws -> Data { response }
}

// MARK: - Built-in Interceptors

/// Adds SDK authentication headers to every request
public struct AuthInterceptor: RequestInterceptor {
    private let appKey: String

    public init(appKey: String) {
        self.appKey = appKey
    }

    public func intercept(request: URLRequest) async throws -> URLRequest {
        var req = request
        req.setValue(appKey, forHTTPHeaderField: "x-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }
}

/// Logs request/response details for debugging
public struct LoggingInterceptor: RequestInterceptor {
    public enum Level: Sendable {
        case minimal, verbose
    }

    private let level: Level

    public init(level: Level = .minimal) {
        self.level = level
    }

    public func intercept(request: URLRequest) async throws -> URLRequest {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        log("→ \(method) \(url)")
        if level == .verbose, let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            log("  Body: \(str.prefix(1024))")
        }
        return request
    }

    public func intercept(response: Data, httpResponse: HTTPURLResponse) async throws -> Data {
        log("← \(httpResponse.statusCode) \(httpResponse.url?.path ?? "")")
        if level == .verbose, let str = String(data: response, encoding: .utf8) {
            log("  Response: \(str.prefix(1024))")
        }
        return response
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[PushCRM Network] \(message)")
        #endif
    }
}
