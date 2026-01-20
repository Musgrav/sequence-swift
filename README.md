# Sequence Swift SDK

A native Swift SDK for integrating Sequence onboarding flows into your iOS apps with pixel-perfect WYSIWYG rendering.

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
3. **IMPORTANT:** For the Dependency Rule, select **Branch** and type `main`
   - Do NOT use a version number - always use branch `main` to get the latest fixes
4. Click **Add Package** and add to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Musgrav/sequence-swift", branch: "main")
]
```

> ⚠️ **Important:** Always use `branch: "main"` instead of a version number to ensure you have the latest rendering fixes and features.

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
            baseURL: "https://screensequence.com" // Optional for self-hosted
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

Use `WebViewOnboardingView` for pixel-perfect WYSIWYG rendering that matches exactly what you see in the editor:

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
                WebViewOnboardingView {
                    // Called when onboarding completes
                    print("Welcome to the app!")
                }
            }
        }
    }
}
```

> ⚠️ **Important:** Always use `WebViewOnboardingView` (not `OnboardingView`). The WebView version renders your flows exactly as designed in the editor with proper scaling and styling.

### 3. Identify Users (Optional)

Associate analytics events with your user IDs:

```swift
// After user authentication
Sequence.shared.identify(userId: "user_12345")

// On logout
Sequence.shared.reset()
```

---

## Authentication Integration (Required for Auth Flows)

**If your onboarding includes sign-in buttons (Apple, Google, or Email), you must implement the `SequenceDelegate` protocol.** This is a prerequisite for any app using authentication in their onboarding flow.

### Overview

| Provider | SDK Behavior | Your Responsibility |
|----------|--------------|---------------------|
| **Apple** | Fully handled by SDK | None - works automatically |
| **Google** | Delegates to your app | Integrate Google Sign-In SDK, call completion method |
| **Email** | Delegates to your app | Implement your auth flow, call completion method |

### Setting Up the Delegate

Create a class that implements `SequenceDelegate` and set it during configuration:

```swift
import Sequence
import GoogleSignIn // If using Google

@main
struct MyApp: App {
    init() {
        // Configure SDK
        Sequence.shared.configure(
            appId: "YOUR_APP_ID",
            apiKey: "YOUR_API_KEY"
        )

        // Set delegate for auth handling
        Sequence.shared.delegate = AuthHandler.shared

        // Configure Google Sign-In (if using Google auth)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
        )
    }
}

class AuthHandler: SequenceDelegate {
    static let shared = AuthHandler()
    private init() {}

    // Implement delegate methods below...
}
```

---

### Apple Sign-In

Apple Sign-In is **fully handled by the SDK**. No implementation required.

When a user taps "Sign in with Apple":
1. SDK presents the Apple Sign-In sheet
2. User authenticates with Face ID/Touch ID
3. SDK verifies the credential with your Sequence backend
4. SDK determines if user is new or returning
5. Flow routes accordingly (new users continue onboarding, returning users exit)

The delegate method is called for your information only:

```swift
func sequence(_ sequence: Sequence, didCompleteAppleSignIn credential: AppleAuthCredential) {
    // Optional: Store user info in your app
    print("Apple Sign-In completed for user: \(credential.userIdentifier)")

    // Available properties:
    // - credential.userIdentifier (stable user ID - always available)
    // - credential.email (only provided on FIRST sign-in)
    // - credential.fullName?.givenName (only on first sign-in)
    // - credential.fullName?.familyName (only on first sign-in)
}

func sequence(_ sequence: Sequence, didFailAppleSignIn error: Error) {
    print("Apple Sign-In failed: \(error)")
}
```

---

### Google Sign-In

Google Sign-In requires the [Google Sign-In SDK](https://developers.google.com/identity/sign-in/ios/start) which you must integrate separately.

#### Step 1: Add Google Sign-In SDK

Add to your `Package.swift`:
```swift
.package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
```

Or via Xcode: File → Add Packages → `https://github.com/google/GoogleSignIn-iOS`

#### Step 2: Configure in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth 2.0 Client ID for iOS
3. Add your bundle ID
4. Download and add `GoogleService-Info.plist` to your project

#### Step 3: Implement the Delegate

```swift
import Sequence
import GoogleSignIn

class AuthHandler: SequenceDelegate {
    static let shared = AuthHandler()

    // Handle the auth.google custom action
    func sequence(_ sequence: Sequence, didReceiveCustomAction identifier: String, awaitingResult: Bool) -> Bool {
        if identifier == "auth.google" {
            performGoogleSignIn()
            return true // We're handling this action
        }
        return false
    }

    private func performGoogleSignIn() {
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            Sequence.shared.sendFailureResult(error: "No root view controller")
            return
        }

        // Find the topmost presented controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        // Present Google Sign-In
        GIDSignIn.sharedInstance.signIn(withPresenting: topController) { result, error in
            // Handle cancellation
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    Sequence.shared.sendCancelledResult()
                } else {
                    Sequence.shared.sendFailureResult(error: error.localizedDescription)
                }
                return
            }

            // Get the ID token
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                Sequence.shared.sendFailureResult(error: "Failed to get Google ID token")
                return
            }

            // Create credential and complete sign-in
            let credential = GoogleAuthCredential(
                idToken: idToken,
                accessToken: user.accessToken.tokenString,
                email: user.profile?.email,
                displayName: user.profile?.name
            )

            // This verifies with backend and sends result to WebView
            Task {
                await Sequence.shared.completeGoogleSignIn(credential: credential)
            }
        }
    }

    // Optional: Called after completion for your own tracking
    func sequence(_ sequence: Sequence, didCompleteGoogleSignIn credential: GoogleAuthCredential) {
        print("Google Sign-In completed for: \(credential.email ?? "unknown")")
    }

    func sequence(_ sequence: Sequence, didFailGoogleSignIn error: Error) {
        print("Google Sign-In failed: \(error)")
    }
}
```

#### How It Works

1. User taps "Sign in with Google" in onboarding
2. SDK calls `sequence(_:didReceiveCustomAction:awaitingResult:)` with `"auth.google"`
3. Your app presents Google Sign-In UI
4. User authenticates with Google
5. Your app calls `Sequence.shared.completeGoogleSignIn(credential:)`
6. SDK verifies the ID token with your Sequence backend
7. Backend checks if user exists (by `google_user_id`)
8. SDK sends `isNewUser` flag back to the onboarding flow
9. Flow routes: new users continue onboarding, returning users exit to main app

---

### Email Sign-In

Email authentication is fully customizable. Implement whatever auth method your app uses (password, magic link, OTP, etc.), then tell the SDK the result.

#### Implement the Delegate

```swift
import Sequence

class AuthHandler: SequenceDelegate {
    static let shared = AuthHandler()

    // Called when email sign-in is requested
    func sequenceDidRequestEmailSignIn(_ sequence: Sequence) {
        presentEmailAuth()
    }

    private func presentEmailAuth() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            Sequence.shared.sendFailureResult(error: "No root view controller")
            return
        }

        // Find topmost controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        // Present your email auth UI
        let emailAuthVC = YourEmailAuthViewController()

        emailAuthVC.onSuccess = { email, firstName, lastName in
            self.completeEmailAuth(email: email, givenName: firstName, familyName: lastName)
        }

        emailAuthVC.onCancel = {
            Sequence.shared.sendCancelledResult()
        }

        emailAuthVC.onError = { errorMessage in
            Sequence.shared.sendFailureResult(error: errorMessage)
        }

        topController.present(emailAuthVC, animated: true)
    }

    private func completeEmailAuth(email: String, givenName: String?, familyName: String?) {
        Task {
            do {
                // Verify with backend to check if new or returning user
                let result = try await Sequence.shared.verifyEmailAuth(
                    email: email,
                    givenName: givenName,
                    familyName: familyName
                )

                // Send success with isNewUser flag
                Sequence.shared.sendSuccessResult(data: [
                    "email": email,
                    "givenName": givenName as Any,
                    "familyName": familyName as Any,
                    "isNewUser": result.isNewUser
                ])
            } catch {
                Sequence.shared.sendFailureResult(error: error.localizedDescription)
            }
        }
    }
}
```

#### Example: Password-Based Auth

```swift
private func authenticateWithPassword(email: String, password: String) {
    // Call your backend to authenticate
    YourAuthService.signIn(email: email, password: password) { [weak self] result in
        switch result {
        case .success(let user):
            // User authenticated - now verify with Sequence
            self?.completeEmailAuth(
                email: user.email,
                givenName: user.firstName,
                familyName: user.lastName
            )

        case .failure(let error):
            Sequence.shared.sendFailureResult(error: error.localizedDescription)
        }
    }
}
```

#### Example: Magic Link/OTP Auth

```swift
// Step 1: Send magic link or OTP
func sendMagicLink(email: String) {
    YourAuthService.sendMagicLink(email: email) { error in
        if let error = error {
            Sequence.shared.sendFailureResult(error: error.localizedDescription)
        } else {
            // Show code entry UI
            self.showCodeEntry(email: email)
        }
    }
}

// Step 2: Verify code
func verifyCode(email: String, code: String) {
    YourAuthService.verifyCode(email: email, code: code) { result in
        switch result {
        case .success(let user):
            // Verify with Sequence backend
            Task {
                do {
                    let result = try await Sequence.shared.verifyEmailAuth(
                        email: email,
                        givenName: user.firstName,
                        familyName: user.lastName
                    )

                    Sequence.shared.sendSuccessResult(data: [
                        "email": email,
                        "isNewUser": result.isNewUser
                    ])
                } catch {
                    Sequence.shared.sendFailureResult(error: error.localizedDescription)
                }
            }

        case .failure(let error):
            Sequence.shared.sendFailureResult(error: error.localizedDescription)
        }
    }
}
```

#### How It Works

1. User taps "Sign in with Email" in onboarding
2. SDK calls `sequenceDidRequestEmailSignIn(_:)`
3. Your app presents your email auth UI
4. User authenticates through your system
5. Your app calls `Sequence.shared.verifyEmailAuth(email:givenName:familyName:)`
6. SDK sends the email to your Sequence backend
7. Backend checks if user exists with that email (and `auth_provider = 'email'`)
8. Your app calls `sendSuccessResult(data:)` with `isNewUser` flag
9. Flow routes: new users continue onboarding, returning users exit to main app

---

### New vs Returning User Routing

All auth methods return an `isNewUser` flag that determines the flow:

| `isNewUser` | Behavior |
|-------------|----------|
| `true` | User continues through onboarding flow |
| `false` | Flow completes immediately, user goes to main app |

Configure this in your Sequence dashboard by setting "New User Screen" and "Returning User Screen" on auth button elements.

The backend determines `isNewUser` by checking:
- **Apple**: Does a user with this `apple_user_id` exist for this app?
- **Google**: Does a user with this `google_user_id` exist for this app?
- **Email**: Does a user with this email and `auth_provider = 'email'` exist for this app?

---

### Complete Auth Handler Example

Here's a complete example implementing all three auth methods:

```swift
import UIKit
import Sequence
import GoogleSignIn

class AuthHandler: SequenceDelegate {
    static let shared = AuthHandler()
    private init() {}

    // MARK: - Apple Sign-In (automatic)

    func sequence(_ sequence: Sequence, didCompleteAppleSignIn credential: AppleAuthCredential) {
        print("Apple Sign-In: \(credential.userIdentifier)")
        // Store locally if needed
        UserDefaults.standard.set(credential.userIdentifier, forKey: "appleUserId")
    }

    func sequence(_ sequence: Sequence, didFailAppleSignIn error: Error) {
        print("Apple Sign-In failed: \(error)")
    }

    // MARK: - Google Sign-In (manual)

    func sequence(_ sequence: Sequence, didReceiveCustomAction identifier: String, awaitingResult: Bool) -> Bool {
        if identifier == "auth.google" {
            performGoogleSignIn()
            return true
        }
        return false
    }

    func sequence(_ sequence: Sequence, didCompleteGoogleSignIn credential: GoogleAuthCredential) {
        print("Google Sign-In: \(credential.email ?? "unknown")")
    }

    func sequence(_ sequence: Sequence, didFailGoogleSignIn error: Error) {
        print("Google Sign-In failed: \(error)")
    }

    // MARK: - Email Sign-In (manual)

    func sequenceDidRequestEmailSignIn(_ sequence: Sequence) {
        presentEmailAuth()
    }

    // MARK: - Private Implementation

    private func performGoogleSignIn() {
        guard let topVC = getTopViewController() else {
            Sequence.shared.sendFailureResult(error: "No view controller")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: topVC) { result, error in
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    Sequence.shared.sendCancelledResult()
                } else {
                    Sequence.shared.sendFailureResult(error: error.localizedDescription)
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                Sequence.shared.sendFailureResult(error: "Failed to get ID token")
                return
            }

            let credential = GoogleAuthCredential(
                idToken: idToken,
                accessToken: user.accessToken.tokenString,
                email: user.profile?.email,
                displayName: user.profile?.name
            )

            Task {
                await Sequence.shared.completeGoogleSignIn(credential: credential)
            }
        }
    }

    private func presentEmailAuth() {
        guard let topVC = getTopViewController() else {
            Sequence.shared.sendFailureResult(error: "No view controller")
            return
        }

        let emailVC = EmailAuthViewController()
        emailVC.onComplete = { result in
            switch result {
            case .success(let email, let firstName, let lastName):
                Task {
                    do {
                        let verifyResult = try await Sequence.shared.verifyEmailAuth(
                            email: email,
                            givenName: firstName,
                            familyName: lastName
                        )
                        Sequence.shared.sendSuccessResult(data: [
                            "email": email,
                            "isNewUser": verifyResult.isNewUser
                        ])
                    } catch {
                        Sequence.shared.sendFailureResult(error: error.localizedDescription)
                    }
                }
            case .cancelled:
                Sequence.shared.sendCancelledResult()
            case .error(let message):
                Sequence.shared.sendFailureResult(error: message)
            }
        }

        topVC.present(emailVC, animated: true)
    }

    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return nil
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

// Helper enum for email auth results
enum EmailAuthResult {
    case success(email: String, firstName: String?, lastName: String?)
    case cancelled
    case error(String)
}
```

---

### Troubleshooting Auth

**Google Sign-In not working:**
1. Verify Google Sign-In SDK is added to your project
2. Check your OAuth client ID is correct
3. Ensure bundle ID matches Google Cloud Console
4. Confirm you return `true` from `didReceiveCustomAction` for `"auth.google"`

**Email auth result not routing correctly:**
1. Ensure you call `verifyEmailAuth()` before `sendSuccessResult()`
2. Check that `isNewUser` is included in the success data
3. Verify your backend logs for errors

**User always treated as new:**
1. Check Sequence backend logs
2. Verify API key is correct
3. Ensure user ID/email is sent correctly

---

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

### WebViewOnboardingView (Recommended)

SwiftUI view that renders your onboarding flow using a WebView for pixel-perfect WYSIWYG rendering. **This is the recommended view to use.**

```swift
WebViewOnboardingView(
    onComplete: (() -> Void)? = nil,
    onDataCollected: (([String: Any]) -> Void)? = nil
)
```

**Why use WebViewOnboardingView:**
- Pixel-perfect rendering that matches the web editor exactly
- Proper scaling on all device sizes
- Full support for all styling options (shadows, gradients, etc.)
- Consistent behavior across iOS versions

### OnboardingView (Legacy)

Native SwiftUI view that renders an approximation of your onboarding flow. **Not recommended for production use** as it may not match the editor exactly.

```swift
OnboardingView(
    onComplete: () -> Void,
    onNativeScreen: ((Screen) -> AnyView)?
)
```

> ⚠️ **Warning:** `OnboardingView` uses native SwiftUI components which may not render identically to what you see in the editor. Always use `WebViewOnboardingView` for production apps.

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

- Documentation: (https://www.screensequence.com/docs#mg-step-by-step)
- Issues: [GitHub Issues](https://github.com/Musgrav/sequence-swift/issues)

## License

MIT License - see LICENSE file for details.

