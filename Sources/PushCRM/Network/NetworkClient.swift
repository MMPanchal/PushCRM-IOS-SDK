import Foundation

/// Thread-safe network client with retry logic
final class NetworkClient {
    private let config: PushCRMConfig
    private let session: URLSession

    init(config: PushCRMConfig) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.waitsForConnectivity = true
        self.session = URLSession(configuration: sessionConfig)
    }

    enum Endpoint: String {
        case register = "/api/sdk/register"
        case events = "/api/sdk/events"
        case identify = "/api/sdk/identify"
        case pushToken = "/api/sdk/push-token"
        case campaignStats = "/api/campaigns"
    }

    struct APIError: Error {
        let statusCode: Int
        let message: String
        var isRetryable: Bool { statusCode >= 500 || statusCode == 429 }
    }

    func post(
        endpoint: Endpoint,
        body: [String: Any],
        retryCount: Int = 0,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: config.baseURL + endpoint.rawValue) else {
            completion(.failure(APIError(statusCode: 0, message: "Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.appKey, forHTTPHeaderField: "X-PushCRM-Key")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                if retryCount < self.config.maxRetries {
                    let delay = pow(2.0, Double(retryCount))
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.post(endpoint: endpoint, body: body, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                let apiError = APIError(statusCode: statusCode, message: "HTTP \(statusCode)")
                if apiError.isRetryable && retryCount < self.config.maxRetries {
                    let delay = pow(2.0, Double(retryCount))
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.post(endpoint: endpoint, body: body, retryCount: retryCount + 1, completion: completion)
                    }
                } else {
                    completion(.failure(apiError))
                }
                return
            }

            if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(.success(json))
            } else {
                completion(.success([:]))
            }
        }.resume()
    }
}
