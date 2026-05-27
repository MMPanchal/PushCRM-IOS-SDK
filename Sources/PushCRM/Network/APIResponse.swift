import Foundation

/// Generic API response wrapping decoded data with HTTP metadata
public struct APIResponse<T: Decodable> {
    public let data: T
    public let statusCode: Int
    public let headers: [AnyHashable: Any]

    public init(data: T, statusCode: Int, headers: [AnyHashable: Any] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// Empty response for endpoints that return no body
public struct EmptyResponse: Decodable {}

/// Standard server error response shape
public struct ServerErrorResponse: Decodable {
    public let error: String?
    public let message: String?
    public let code: String?
}
