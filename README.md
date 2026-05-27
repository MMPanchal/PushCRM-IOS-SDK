# PushCRM iOS SDK

A lightweight, modular push notification and analytics SDK for iOS applications.

## Installation

### Swift Package Manager

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/your-org/PushCRM-iOS.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter repository URL.

## Quick Start

```swift
import PushCRM

// In AppDelegate.didFinishLaunchingWithOptions:
let config = PushCRMConfig(
    appKey: "your-app-key",
    baseURL: "https://your-pushcrm-server.com"
)
PushCRM.shared.initialize(config: config)

// Identify user
PushCRM.shared.identify(userId: "user_123", properties: ["name": "John"])

// Track events
PushCRM.shared.track(event: "purchase", properties: ["amount": 29.99])

// Register push token (in didRegisterForRemoteNotificationsWithDeviceToken)
PushCRM.shared.registerPushToken(deviceToken)

// Track push delivery (in Notification Service Extension)
PushCRM.shared.pushDelivered(campaignId: "campaign_id")

// Track push open (in userNotificationCenter didReceive)
PushCRM.shared.pushOpened(campaignId: "campaign_id")
```

## Public SDK API

All methods are thread-safe and can be called from any thread.

### Methods

| Method | Description |
|--------|-------------|
| `initialize(config:)` | One-time SDK setup. Call in `AppDelegate.didFinishLaunchingWithOptions`. Idempotent — safe to call multiple times. |
| `identify(userId:properties:)` | Associate a known user with all subsequent events. Call after login. |
| `track(event:properties:)` | Track a custom event. Events are queued offline, batched, and retried automatically. |
| `registerPushToken(_:)` | Register raw APNs `Data` token. Deduplicates — re-registering same token is a no-op. |
| `registerPushToken(string:)` | Register a token string directly (useful for FCM or testing). |
| `resetUser()` | Clear user identity on logout. Ends session, starts a new anonymous session. |
| `pushDelivered(campaignId:)` | Track push delivery (call in Notification Service Extension). |
| `pushOpened(campaignId:)` | Track push open (call in `userNotificationCenter didReceive`). |
| `flush()` | Force-upload all queued events immediately. |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `Bool` | Whether the SDK has been initialized |
| `currentUserId` | `String?` | Currently identified user ID, or `nil` if anonymous |
| `deviceId` | `String?` | Auto-generated persistent device identifier |

### Integration Examples

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let config = PushCRMConfig(
        appKey: "pk_live_abc123",
        baseURL: "https://api.pushcrm.io"
    )
    PushCRM.shared.initialize(config: config)
    return true
}

func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushCRM.shared.registerPushToken(deviceToken)
}

// After login
PushCRM.shared.identify(userId: "user_42", properties: [
    "name": "Jane Smith",
    "plan": "enterprise"
])

// Track events anywhere
PushCRM.shared.track(event: "purchase", properties: [
    "amount": 29.99,
    "currency": "USD"
])

// On logout
PushCRM.shared.resetUser()
```

### Safety Guarantees

- Calling any method before `initialize()` logs a debug warning and no-ops
- All methods dispatch to a serial queue — no race conditions
- Events persist to disk — survive app crashes and restarts
- Push token is deduplicated — network call only on change
- `resetUser()` preserves device ID and push token registration

## Networking Layer

Production-grade async/await API client with interceptor pipeline.

```
Sources/PushCRM/Network/
├── APIClient.swift            # Generic async/await client with retry + interceptors
├── APIRequest.swift           # Typed request model (method, path, body, query)
├── APIResponse.swift          # Generic response wrapper with HTTP metadata
├── NetworkError.swift         # Typed error enum with isRetryable
├── RequestInterceptor.swift   # Interceptor protocol + Auth/Logging built-ins
└── NetworkClient.swift        # Legacy callback-based client
```

**Features:**
- Generic `send<Body, Response>` with full Codable type safety
- Retry with exponential backoff + jitter (5xx, 429, timeout, no connection)
- Composable interceptor pipeline (auth, logging, custom transforms)
- Configurable timeout per-request or globally
- `Sendable` conformance for structured concurrency
- Automatic snake_case ↔ camelCase JSON key conversion

**Usage:**
```swift
let client = APIClient(pushCRMConfig: config)

struct EventPayload: Encodable { let events: [String] }
struct EventResult: Decodable { let accepted: Int }

let request = APIRequest(
    method: .post,
    path: "/api/sdk/events",
    body: EventPayload(events: ["purchase"])
)
let response = try await client.send(request, responseType: EventResult.self)
```

## Offline Event Queue

Offline-first event queue with batch upload, retry, and file-based persistence.

```
Sources/PushCRM/Queue/
├── OfflineEventQueue.swift    # Main orchestrator (batch flush, retry, timer)
├── Event.swift                # Codable event model + AnyCodable wrapper
├── EventStore.swift           # Actor-based file persistence (atomic JSON writes)
└── EventQueue.swift           # Legacy queue
```

**Flush Triggers:**
- Queue reaches 20 events (configurable `batchSize`)
- Timer fires every 30 seconds (configurable `flushInterval`)
- App enters background (`stop()` persists + cancels timer)
- Manual `flush()` / `flushAsync()` call

**Data Flow:**
```
enqueue() ──→ inMemoryQueue (DispatchQueue-protected)
                    │
         ┌──────────┴──────────┐
         │                     │
    count ≥ 20            Timer (30s)
         │                     │
         └──────────┬──────────┘
                    ▼
              triggerFlush()
                    │
                    ▼
         uploadBatch() [async]
           ┌────────┴────────┐
        Success            Failure
           │                  │
    Remove from queue    Increment retryCount
    Persist to disk      Drop if > maxRetries
                         Persist to disk
```

**Usage:**
```swift
let queue = OfflineEventQueue(
    apiClient: client,
    config: .init(batchSize: 20, flushInterval: 30),
    deviceId: storage.deviceId
)

queue.start()  // Restore persisted events + start timer
queue.enqueue(name: "purchase", properties: ["amount": 29.99], userId: "user_123")
queue.stop()   // Persist + cancel timer (call on app background)
```

| Concern | Solution |
|---------|----------|
| Thread safety | Serial `DispatchQueue` for all state mutations |
| Persistence | Actor-isolated file I/O with atomic writes to Application Support |
| Retry | Per-event `retryCount`; dropped after `maxRetries` exceeded |
| Upload | Uses async/await `APIClient` with its own exponential backoff |
| Max queue cap | 1000 events (configurable) — prevents unbounded memory growth |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   PushCRM (Facade)                   │
│              Singleton Entry Point                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐ │
│  │ Identity │  │  Session  │  │  PushTokenManager │ │
│  │ Manager  │  │  Manager  │  │                   │ │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘ │
│       │              │                  │            │
│       ▼              ▼                  ▼            │
│  ┌──────────────────────────────────────────────┐   │
│  │              EventQueue                       │   │
│  │   (Offline Queue + Batch Flush + Retry)       │   │
│  └───────────────────┬──────────────────────────┘   │
│                      │                               │
│       ┌──────────────┼──────────────┐               │
│       ▼              ▼              ▼               │
│  ┌─────────┐  ┌────────────┐  ┌──────────┐        │
│  │ Network │  │  Storage   │  │  Config  │        │
│  │ Client  │  │  Manager   │  │          │        │
│  └─────────┘  └────────────┘  └──────────┘        │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| **Core/PushCRM** | Facade pattern, lifecycle management, public API |
| **Config** | SDK configuration, defaults |
| **Network** | Async/await API client, interceptors, retry with exponential backoff |
| **Storage** | UserDefaults persistence, thread-safe read/write |
| **Queue** | Offline-first event batching, file persistence, flush timer |
| **Session** | Session start/end, timeout-based rotation |
| **Identity** | User identification, device registration |
| **Push** | APNs token registration, delivery/open tracking |

## Design Patterns

- **Facade** — `PushCRM` singleton provides simple public API
- **Observer** — App lifecycle notifications for session/flush management
- **Queue** — Serial dispatch queue for thread safety
- **Strategy** — Retry with exponential backoff + jitter in APIClient
- **Repository** — StorageManager abstracts persistence layer
- **Actor** — EventStore uses Swift actor for file I/O isolation
- **Interceptor** — Composable request/response pipeline in networking

## Thread Safety

- All public methods dispatch to a serial queue (`com.pushcrm.sdk`)
- OfflineEventQueue uses dedicated serial `DispatchQueue` for state
- EventStore uses Swift actor isolation for atomic file operations
- StorageManager uses dedicated file queue for I/O
- APIClient is `Sendable`-conformant for structured concurrency

## Requirements

- iOS 13.0+
- Swift 5.9+
