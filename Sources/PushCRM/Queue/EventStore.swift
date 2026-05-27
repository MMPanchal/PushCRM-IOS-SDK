import Foundation

/// Actor-based file persistence for the event queue.
/// Stores events as a JSON array in the app's Application Support directory.
actor EventStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "pushcrm_event_queue.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PushCRM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(fileName)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Read

    func loadAll() -> [Event] {
        guard let data = try? Data(contentsOf: fileURL),
              let events = try? decoder.decode([Event].self, from: data)
        else { return [] }
        return events
    }

    // MARK: - Write

    func save(_ events: [Event]) {
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func append(_ events: [Event]) {
        var existing = loadAll()
        existing.append(contentsOf: events)
        save(existing)
    }

    func remove(ids: Set<String>) {
        var existing = loadAll()
        existing.removeAll { ids.contains($0.id) }
        save(existing)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func count() -> Int {
        loadAll().count
    }
}
