# PushCRM Example App

A SwiftUI sample app demonstrating full integration with the PushCRM iOS SDK.

## Features

- Login/Register form with validation
- PushCRM SDK initialization
- User identification (email as unique key)
- Event tracking ("User Login")
- Offline queue with automatic flush
- Console logging for debugging

## Setup

### 1. Configure Backend

Ensure your PushCRM backend is running:

```bash
cd /path/to/PushCRM
npm run dev
```

### 2. Run SQL Migration

Execute in Supabase SQL Editor:

```sql
-- Add email unique constraint to user_profiles
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_email_key UNIQUE (email);

-- Create user_profile_events table
CREATE TABLE IF NOT EXISTS user_profile_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_profile_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    event_name TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profile_events_profile_id ON user_profile_events(user_profile_id);
CREATE INDEX IF NOT EXISTS idx_user_profile_events_created_at ON user_profile_events(created_at DESC);
```

### 3. Register SDK App Key

Insert your app key into `sdk_apps` table:

```sql
INSERT INTO sdk_apps (app_key, app_secret, name)
VALUES ('pk_live_pushcrm_demo', 'sk_secret_demo', 'PushCRM Demo App');
```

### 4. Update Config

Edit `PushCRMExample/Config/AppConfig.swift`:

```swift
enum AppConfig {
    static let pushCRMAppKey = "pk_live_pushcrm_demo"  // Your app key
    static let pushCRMBaseURL = "http://localhost:3000"  // Your backend URL
    static let sdkVersion = "1.0.0"
}
```

### 5. Open in Xcode

```bash
cd Example
open Package.swift
```

Or add the Example folder to an Xcode workspace.

### 6. Run on Simulator

Select an iOS 16+ simulator and run.

## Testing Flow

1. Launch the app
2. Enter:
   - Name: `John Doe`
   - Email: `john@example.com`
   - Mobile: `+919876543210`
   - Password: `test123`
3. Tap **Submit**
4. Check console logs for SDK activity
5. Verify in PushCRM Dashboard:
   - User Profiles → User appears with email
   - Events → "User Login" event linked to user

## Expected Console Output

```
[PushCRMService] ✅ SDK initialized with baseURL: http://localhost:3000
[PushCRMService] 👤 Identified user: john@example.com
[PushCRMService] 📊 Tracked 'User Login' for: john@example.com
[PushCRMService] 🔄 Flushed event queue
[PushCRM Network] → POST /api/sdk/identify
[PushCRM Network] ← 200 /api/sdk/identify
[PushCRM Network] → POST /api/sdk/events
[PushCRM Network] ← 200 /api/sdk/events
[LoginViewModel] ✅ Submit complete for: john@example.com
```

## Sample API Payloads

### POST /api/sdk/identify

```json
{
  "userId": "john@example.com",
  "deviceId": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "properties": {
    "name": "John Doe",
    "email": "john@example.com",
    "mobile": "+919876543210",
    "platform": "iOS"
  }
}
```

### POST /api/sdk/events

```json
{
  "deviceId": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "events": [
    {
      "event": "User Login",
      "userId": "john@example.com",
      "timestamp": "2024-01-15T10:30:00Z",
      "properties": {
        "platform": "iOS",
        "screen": "Login",
        "login_method": "email",
        "sdk_version": "1.0.0",
        "email": "john@example.com"
      }
    }
  ]
}
```

## Architecture

```
PushCRMExample/
├── App/
│   └── PushCRMExampleApp.swift    # Entry point, SDK init
├── Config/
│   └── AppConfig.swift            # Environment configuration
├── Models/
│   └── UserFormData.swift         # Form data model
├── ViewModels/
│   └── LoginViewModel.swift       # MVVM business logic
├── Views/
│   └── LoginView.swift            # SwiftUI UI
└── Services/
    ├── PushCRMService.swift        # SDK integration layer
    └── FormValidator.swift         # Input validation
```
