# Sequence Swift SDK

A native Swift SDK for integrating Sequence onboarding flows into your iOS apps.

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add Sequence to your project via SPM:

1. In Xcode, go to **File → Add Packages**
2. Enter the repository URL:
   ```
   https://github.com/Musgrav/sequence-swift
   ```
3. Select your version rules and add to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Musgrav/sequence-swift", from: "1.0.0")
]
```

## Quick Start

### 1. Configure the SDK

Initialize Sequence in your App's init or AppDelegate:

```swift
import Sequence

@main
struct MyApp: App {
    init() {
        Sequence.shared.configure(
            appId: "YOUR_APP_ID",
            apiKey: "YOUR_API_KEY",
            baseURL: "https://your-sequence-instance.com" // Optional for self-hosted
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Show Onboarding

Use `OnboardingView` to display your onboarding flow:

```swift
import SwiftUI
import Sequence

struct ContentView: View {
    @StateObject private var sequence = Sequence.shared
    
    var body: some View {
        Group {
            if sequence.isOnboardingCompleted {
                // Your main app content
                MainAppView()
            } else {
                OnboardingView {
                    // Called when onboarding completes
                    print("Welcome to the app!")
                }
            }
        }
    }
}
```

### 3. Identify Users (Optional)

Associate analytics events with your user IDs:

```swift
// After user authentication
Sequence.shared.identify(userId: "user_12345")

// On logout
Sequence.shared.reset()
```

## Features

### Automatic Event Tracking

The SDK automatically tracks:

- `onboarding_started` - When user begins onboarding
- `screen_viewed` - When each screen is displayed
- `screen_completed` - When user completes a screen
- `screen_skipped` - When user skips a screen
- `button_tapped` - When user taps a button
- `onboarding_completed` - When user finishes onboarding

Events are batched and sent every 10 seconds or when the batch reaches 20 events.

### Manual Event Tracking

You can also track custom events:

```swift
Sequence.shared.track(
    eventType: .buttonTapped,
    screenId: "screen_123",
    properties: ["button_text": "Subscribe"]
)
```

### Custom Native Screens

For screens that require native functionality, use the `onNativeScreen` callback:

```swift
OnboardingView(
    onComplete: { /* ... */ },
    onNativeScreen: { screen in
        // Return your custom SwiftUI view
        if screen.content.identifier == "custom_permissions" {
            return AnyView(CustomPermissionsView())
        }
        return AnyView(EmptyView())
    }
)
```

### Reset Onboarding

For testing or showing onboarding again:

```swift
Sequence.shared.resetOnboarding()
```

## Configuration

| Parameter | Type | Description |
|-----------|------|-------------|
| `appId` | String | Your Sequence App ID |
| `apiKey` | String | Your Sequence API Key |
| `baseURL` | String? | Custom API URL (for self-hosted) |

Find your credentials in the Sequence dashboard under **Settings**.

## API Reference

### Sequence

Main singleton class for SDK configuration and event tracking.

```swift
// Configuration
Sequence.shared.configure(appId:apiKey:baseURL:)

// User identification
Sequence.shared.identify(userId:)
Sequence.shared.reset()

// Event tracking
Sequence.shared.track(eventType:screenId:properties:)
Sequence.shared.trackScreenViewed(screenId:screenName:)
Sequence.shared.trackScreenCompleted(screenId:screenName:)
Sequence.shared.trackScreenSkipped(screenId:screenName:)
Sequence.shared.trackButtonTapped(screenId:buttonText:)

// Onboarding state
Sequence.shared.isOnboardingCompleted
Sequence.shared.markOnboardingCompleted()
Sequence.shared.resetOnboarding()

// Manual flush
Sequence.shared.flush()
```

### OnboardingView

SwiftUI view that renders the complete onboarding flow.

```swift
OnboardingView(
    onComplete: () -> Void,
    onNativeScreen: ((Screen) -> AnyView)?
)
```

## Models

### Screen Types

- `welcome` - Welcome/intro screens
- `feature` - Feature highlights
- `carousel` - Multi-slide carousels
- `permission` - Permission requests
- `celebration` - Completion celebrations
- `native` - Custom native screens

### Event Types

- `screenViewed`
- `screenCompleted`
- `screenSkipped`
- `buttonTapped`
- `onboardingStarted`
- `onboardingCompleted`

## Error Handling

The SDK provides detailed error types:

```swift
do {
    let config = try await Sequence.shared.fetchConfig()
} catch SequenceError.notConfigured {
    print("SDK not configured")
} catch SequenceError.invalidCredentials {
    print("Invalid API key")
} catch SequenceError.networkError(let message) {
    print("Network error: \(message)")
}
```

## Support

- Documentation: [https://docs.sequence.so](https://docs.sequence.so)
- Issues: [GitHub Issues](https://github.com/Musgrav/sequence-swift/issues)

## License

MIT License - see LICENSE file for details.

