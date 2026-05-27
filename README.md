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

## Data Flow

```
User Action → PushCRM.track()
    → EventQueue.enqueue() [thread-safe, NSLock]
        → Persisted to Storage (offline support)
        → Timer triggers flush every 30s
            → NetworkClient.post() [batch upload]
                → Retry with exponential backoff on failure
                → Clear from queue on success
```

## Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| **Core/PushCRM** | Facade pattern, lifecycle management, public API |
| **Config** | SDK configuration, defaults |
| **Network** | HTTP client, retry with exponential backoff |
| **Storage** | UserDefaults persistence, thread-safe read/write |
| **Queue** | Event batching, offline queue, flush timer |
| **Session** | Session start/end, timeout-based rotation |
| **Identity** | User identification, device registration |
| **Push** | APNs token registration, delivery/open tracking |

## Design Patterns

- **Facade** — `PushCRM` singleton provides simple public API
- **Observer** — App lifecycle notifications for session/flush management
- **Queue** — Serial dispatch queue for thread safety
- **Strategy** — Retry with exponential backoff in NetworkClient
- **Repository** — StorageManager abstracts persistence layer

## Thread Safety

- All public methods dispatch to a serial queue (`com.pushcrm.sdk`)
- EventQueue uses `NSLock` for queue mutations
- StorageManager uses dedicated file queue for I/O

## Requirements

- iOS 13.0+
- Swift 5.9+
