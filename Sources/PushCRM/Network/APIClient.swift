import Foundation

/// Configuration for APIClient behavior
public struct APIClientConfig {
    public let baseURL: String
    public let timeoutInterval: TimeInterval
    public let maxRetries: Int
    public let retryBaseDelay: TimeInterval
    public let interceptors: [RequestInterceptor]

    public init(
        baseURL: String,
        timeoutInterval: TimeInterval = 30,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1.0,
        interceptors: [RequestInterceptor] = []
    ) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.interceptors = interceptors
    }
}

/// Production-grade generic API client with async/await, retry, and interceptors
@available(iOS 13.0, macOS 12.0, *)
public final class APIClient: Sendable {
    private let config: APIClientConfig
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(config: APIClientConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutInterval
        sessionConfig.timeoutIntervalForResource = config.timeoutInterval * 3
        sessionConfig.waitsForConnectivity = true
        self.session = URLSession(configuration: sessionConfig)

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    /// Convenience initializer from PushCRMConfig
    public convenience init(pushCRMConfig: PushCRMConfig) {
        let interceptors: [RequestInterceptor] = [
            AuthInterceptor(appKey: pushCRMConfig.appKey),
            LoggingInterceptor(level: .minimal)
        ]
        self.init(config: APIClientConfig(
            baseURL: pushCRMConfig.baseURL,
            maxRetries: pushCRMConfig.maxRetries,
            interceptors: interceptors
        ))
    }

    // MARK: - Public API

    /// Execute a request and decode the response
    @discardableResult
    public func send<Body: Encodable, Response: Decodable>(
        _ request: APIRequest<Body>,
        responseType: Response.Type
    ) async throws -> APIResponse<Response> {
        var urlRequest = try request.urlRequest(baseURL: config.baseURL, encoder: encoder)
        urlRequest = try await applyRequestInterceptors(urlRequest)
        return try await execute(urlRequest, responseType: responseType, attempt: 0)
    }

    /// Fire-and-forget variant for requests with no meaningful response
    public func send<Body: Encodable>(_ request: APIRequest<Body>) async throws {
        let _: APIResponse<EmptyResponse> = try await send(request, responseType: EmptyResponse.self)
    }

    // MARK: - Execution with Retry

    private func execute<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type,
        attempt: Int
    ) async throws -> APIResponse<Response> {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown("Invalid response type")
            }

            let interceptedData = try await applyResponseInterceptors(data, httpResponse: httpResponse)

            guard (200...299).contains(httpResponse.statusCode) else {
                let error = NetworkError.httpError(statusCode: httpResponse.statusCode, data: interceptedData)
                if error.isRetryable && attempt < config.maxRetries {
                    return try await retry(request, responseType: responseType, attempt: attempt, error: error)
                }
                throw error
            }

            let decoded: Response
            if Response.self == EmptyResponse.self {
                decoded = EmptyResponse() as! Response
            } else {
                do {
                    decoded = try decoder.decode(Response.self, from: interceptedData)
                } catch {
                    throw NetworkError.decodingFailed(error.localizedDescription)
                }
            }

            return APIResponse(
                data: decoded,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields
            )
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            let networkError = mapURLError(urlError)
            if networkError.isRetryable && attempt < config.maxRetries {
                return try await retry(request, responseType: responseType, attempt: attempt, error: networkError)
            }
            throw networkError
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }
    }

    private func retry<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type,
        attempt: Int,
        error: NetworkError
    ) async throws -> APIResponse<Response> {
        let delay = config.retryBaseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        let totalDelay = UInt64((delay + jitter) * 1_000_000_000)

        try await Task.sleep(nanoseconds: totalDelay)

        if Task.isCancelled {
            throw NetworkError.cancelled
        }

        return try await execute(request, responseType: responseType, attempt: attempt + 1)
    }

    // MARK: - Interceptor Pipeline

    private func applyRequestInterceptors(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        for interceptor in config.interceptors {
            req = try await interceptor.intercept(request: req)
        }
        return req
    }

    private func applyResponseInterceptors(_ data: Data, httpResponse: HTTPURLResponse) async throws -> Data {
        var result = data
        for interceptor in config.interceptors {
            result = try await interceptor.intercept(response: result, httpResponse: httpResponse)
        }
        return result
    }

    // MARK: - Error Mapping

    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut: return .timeout
        case .notConnectedToInternet, .networkConnectionLost: return .noConnection
        case .cancelled: return .cancelled
        default: return .unknown(error.localizedDescription)
        }
    }
}
