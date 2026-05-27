import Foundation

/// HTTP methods supported by the API client
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Generic API request definition
public struct APIRequest<Body: Encodable> {
    public let method: HTTPMethod
    public let path: String
    public let headers: [String: String]
    public let queryItems: [URLQueryItem]
    public let body: Body?
    public let timeoutInterval: TimeInterval?

    public init(
        method: HTTPMethod = .get,
        path: String,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Body? = nil,
        timeoutInterval: TimeInterval? = nil
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
}

/// Convenience type for requests with no body
public typealias EmptyBody = Empty

public struct Empty: Encodable {}

/// Extension to build URLRequest from APIRequest
extension APIRequest {
    func urlRequest(baseURL: String, encoder: JSONEncoder) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let timeout = timeoutInterval {
            request.timeoutInterval = timeout
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body, !(body is Empty) {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encodingFailed(error.localizedDescription)
            }
        }

        return request
    }
}
