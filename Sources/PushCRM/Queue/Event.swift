import Foundation

/// Represents a single trackable event in the queue
public struct Event: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let properties: [String: AnyCodable]
    public let deviceId: String
    public let userId: String?
    public let sessionId: String?
    public let timestamp: Date
    public var retryCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, properties
        case deviceId = "deviceId"
        case userId = "userId"
        case sessionId = "sessionId"
        case timestamp
        case retryCount = "retryCount"
    }

    public init(
        name: String,
        properties: [String: Any],
        deviceId: String,
        userId: String?,
        sessionId: String?
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.properties = properties.mapValues { AnyCodable($0) }
        self.deviceId = deviceId
        self.userId = userId
        self.sessionId = sessionId
        self.timestamp = Date()
        self.retryCount = 0
    }
}

/// Type-erased Codable wrapper for heterogeneous property values
public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else if container.decodeNil() { value = NSNull() }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        case is NSNull: try container.encodeNil()
        default: try container.encodeNil()
        }
    }
}

/// Server-format event for API payload (maps "name" → "event", excludes internal fields)
struct ServerEvent: Encodable {
    let event: String
    let properties: [String: AnyCodable]
    let deviceId: String
    let userId: String?
    let sessionId: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case event, properties, timestamp
        case deviceId = "deviceId"
        case userId = "userId"
        case sessionId = "sessionId"
    }

    init(from event: Event) {
        self.event = event.name
        self.properties = event.properties
        self.deviceId = event.deviceId
        self.userId = event.userId
        self.sessionId = event.sessionId
        self.timestamp = event.timestamp
    }
}

/// Batch payload sent to the server
struct EventBatchPayload: Encodable {
    let events: [ServerEvent]
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case events
        case deviceId = "deviceId"
    }

    init(events: [Event], deviceId: String) {
        self.events = events.map { ServerEvent(from: $0) }
        self.deviceId = deviceId
    }
}

/// Server response for event batch upload
struct EventBatchResponse: Decodable {
    let accepted: Int?
    let message: String?
}
