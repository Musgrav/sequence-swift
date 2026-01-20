// Sequence Swift SDK
// https://github.com/your-repo/sequence

import Foundation
import SwiftUI
import Combine
import AuthenticationServices

// MARK: - Auth Credentials

/// Credential received from Sign In with Apple.
///
/// This is passed to `sequence(_:didCompleteAppleSignIn:)` after successful Apple Sign-In.
/// The SDK handles verification automatically - you don't need to do anything with this
/// unless you want to store the user info locally.
///
/// - Important: `email` and `fullName` are only provided on the user's FIRST sign-in.
///   Apple does not send this info on subsequent sign-ins, so store it if needed.
public struct AppleAuthCredential {
    /// Stable user identifier. Always available and consistent across sign-ins.
    public let userIdentifier: String

    /// Identity token for backend verification. Used by SDK automatically.
    public let identityToken: Data?

    /// Authorization code for backend use.
    public let authorizationCode: Data?

    /// User's email. Only provided on FIRST sign-in.
    public let email: String?

    /// User's full name. Only provided on FIRST sign-in.
    public let fullName: PersonNameComponents?

    public var identityTokenString: String? {
        identityToken.flatMap { String(data: $0, encoding: .utf8) }
    }

    public var authorizationCodeString: String? {
        authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// Credential for Google Sign-In.
///
/// Create this from the GoogleSignIn SDK result and pass to `completeGoogleSignIn(credential:)`.
///
/// Example:
/// ```swift
/// let credential = GoogleAuthCredential(
///     idToken: user.idToken!.tokenString,
///     accessToken: user.accessToken.tokenString,
///     email: user.profile?.email,
///     displayName: user.profile?.name
/// )
/// await Sequence.shared.completeGoogleSignIn(credential: credential)
/// ```
public struct GoogleAuthCredential {
    /// Google ID token (JWT). Required for backend verification.
    public let idToken: String

    /// Access token for Google APIs. Optional.
    public let accessToken: String?

    /// User's email address.
    public let email: String?

    /// User's display name.
    public let displayName: String?

    public init(idToken: String, accessToken: String? = nil, email: String? = nil, displayName: String? = nil) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.email = email
        self.displayName = displayName
    }
}

/// Result of a permission request
public enum PermissionResult {
    case granted
    case denied
    case notDetermined
}

// MARK: - Sequence Delegate Protocol

/// Delegate protocol for handling authentication and custom actions in onboarding flows.
///
/// **Important:** If your onboarding flow includes any sign-in buttons (Apple, Google, or Email),
/// you MUST implement this protocol. This is a prerequisite for apps using authentication.
///
/// ## Authentication Overview
///
/// | Provider | SDK Behavior | Your Responsibility |
/// |----------|--------------|---------------------|
/// | Apple | Fully automatic | None - just set delegate for optional callbacks |
/// | Google | Delegates to app | Implement `didReceiveCustomAction` for "auth.google" |
/// | Email | Delegates to app | Implement `sequenceDidRequestEmailSignIn` |
///
/// ## Quick Setup
///
/// ```swift
/// // 1. Create handler class
/// class AuthHandler: SequenceDelegate {
///     static let shared = AuthHandler()
///     // Implement methods...
/// }
///
/// // 2. Set delegate during app init
/// Sequence.shared.delegate = AuthHandler.shared
/// ```
///
/// See README.md for complete implementation examples.
@MainActor
public protocol SequenceDelegate: AnyObject {

    // MARK: - Apple Sign-In (Automatic)

    /// Called when Sign In with Apple completes successfully.
    ///
    /// **Note:** Apple Sign-In is fully handled by the SDK. This callback is informational only.
    /// The SDK automatically verifies the credential with your backend and routes the flow.
    ///
    /// - Important: `email` and `fullName` are only provided on the user's FIRST sign-in.
    ///   Store these values if needed, as subsequent sign-ins won't include them.
    ///
    /// - Parameters:
    ///   - sequence: The Sequence instance
    ///   - credential: The Apple auth credential containing user info
    func sequence(_ sequence: Sequence, didCompleteAppleSignIn credential: AppleAuthCredential)

    /// Called when Sign In with Apple fails.
    func sequence(_ sequence: Sequence, didFailAppleSignIn error: Error)

    // MARK: - Google Sign-In (Manual)

    /// Called after Google Sign-In completes (for your tracking purposes).
    ///
    /// **Note:** You must handle the actual Google Sign-In flow yourself via `didReceiveCustomAction`.
    /// This callback is called after you call `completeGoogleSignIn(credential:)`.
    func sequence(_ sequence: Sequence, didCompleteGoogleSignIn credential: GoogleAuthCredential)

    /// Called when Google Sign-In fails.
    func sequence(_ sequence: Sequence, didFailGoogleSignIn error: Error)

    // MARK: - Email Sign-In (Manual)

    /// Called when email sign-in is requested from the onboarding flow.
    ///
    /// **You must implement this** if your onboarding includes email sign-in buttons.
    ///
    /// Your implementation should:
    /// 1. Present your email authentication UI (password, magic link, OTP, etc.)
    /// 2. After successful auth, call `Sequence.shared.verifyEmailAuth(email:givenName:familyName:)`
    /// 3. Then call `Sequence.shared.sendSuccessResult(data: ["isNewUser": result.isNewUser, ...])`
    /// 4. On failure, call `Sequence.shared.sendFailureResult(error:)`
    /// 5. On cancel, call `Sequence.shared.sendCancelledResult()`
    ///
    /// Example:
    /// ```swift
    /// func sequenceDidRequestEmailSignIn(_ sequence: Sequence) {
    ///     let emailVC = MyEmailAuthViewController()
    ///     emailVC.onSuccess = { email, firstName, lastName in
    ///         Task {
    ///             let result = try await Sequence.shared.verifyEmailAuth(
    ///                 email: email, givenName: firstName, familyName: lastName
    ///             )
    ///             Sequence.shared.sendSuccessResult(data: ["email": email, "isNewUser": result.isNewUser])
    ///         }
    ///     }
    ///     present(emailVC, animated: true)
    /// }
    /// ```
    func sequenceDidRequestEmailSignIn(_ sequence: Sequence)

    // MARK: - Custom Actions

    /// Called for custom action identifiers, including Google Sign-In ("auth.google").
    ///
    /// **You must implement this** for Google Sign-In and any custom actions in your flow.
    ///
    /// For Google Sign-In (`identifier == "auth.google"`):
    /// 1. Present Google Sign-In using the GoogleSignIn SDK
    /// 2. On success, call `Sequence.shared.completeGoogleSignIn(credential:)`
    /// 3. On failure, call `Sequence.shared.sendFailureResult(error:)`
    /// 4. On cancel, call `Sequence.shared.sendCancelledResult()`
    /// 5. Return `true` to indicate you're handling this action
    ///
    /// Example:
    /// ```swift
    /// func sequence(_ sequence: Sequence, didReceiveCustomAction identifier: String, awaitingResult: Bool) -> Bool {
    ///     if identifier == "auth.google" {
    ///         GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
    ///             guard let user = result?.user, let idToken = user.idToken?.tokenString else {
    ///                 Sequence.shared.sendFailureResult(error: "Failed")
    ///                 return
    ///             }
    ///             let credential = GoogleAuthCredential(idToken: idToken, ...)
    ///             Task { await Sequence.shared.completeGoogleSignIn(credential: credential) }
    ///         }
    ///         return true
    ///     }
    ///     return false
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - sequence: The Sequence instance
    ///   - identifier: The action identifier (e.g., "auth.google", "myapp.subscribe")
    ///   - awaitingResult: If true, you must call sendSuccessResult/sendFailureResult/sendCancelledResult
    /// - Returns: `true` if you handled the action, `false` otherwise
    func sequence(_ sequence: Sequence, didReceiveCustomAction identifier: String, awaitingResult: Bool) -> Bool
}

// Default implementations make all methods optional
public extension SequenceDelegate {
    func sequence(_ sequence: Sequence, didCompleteAppleSignIn credential: AppleAuthCredential) {}
    func sequence(_ sequence: Sequence, didFailAppleSignIn error: Error) {}
    func sequence(_ sequence: Sequence, didCompleteGoogleSignIn credential: GoogleAuthCredential) {}
    func sequence(_ sequence: Sequence, didFailGoogleSignIn error: Error) {}
    func sequenceDidRequestEmailSignIn(_ sequence: Sequence) {}
    func sequence(_ sequence: Sequence, didReceiveCustomAction identifier: String, awaitingResult: Bool) -> Bool { return false }
}

/// Main entry point for Sequence SDK
/// Initialize once in your app (e.g., in AppDelegate or @main App)
@MainActor
public final class Sequence: ObservableObject {
    
    // MARK: - Singleton

    /// Shared instance of Sequence
    public static let shared = Sequence()

    // MARK: - Delegate

    /// Delegate for receiving auth callbacks and custom action events
    public weak var delegate: SequenceDelegate?

    /// Internal callback for WebView to send results back
    internal var webViewResultCallback: ((NativeActionResult) -> Void)?

    // MARK: - Published Properties
    
    /// Current onboarding configuration fetched from server
    @Published public private(set) var config: OnboardingConfig?
    
    /// Whether the SDK is currently fetching configuration
    @Published public private(set) var isLoading = false
    
    /// Whether onboarding has been completed by this user
    @Published public private(set) var isOnboardingCompleted = false
    
    /// Current error if any
    @Published public private(set) var error: SequenceError?
    
    // MARK: - Configuration Properties (internal for WebView access)

    internal private(set) var appId: String?
    internal private(set) var apiKey: String?
    internal private(set) var baseURL: String = "https://your-domain.com" // Default, override in configure
    private var userId: String?
    private var deviceId: String
    private var eventQueue: [OnboardingEvent] = []
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval = 10.0 // Flush events every 10 seconds
    private let maxBatchSize = 20
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Session Tracking Properties

    /// Current onboarding session ID (unique per app open)
    internal private(set) var currentSessionId: String?

    /// Time when the current session started
    private var sessionStartTime: Date?

    /// Current screen being viewed
    internal private(set) var currentScreenId: String?

    /// Time when user entered the current screen
    private var currentScreenStartTime: Date?

    /// Number of screens viewed in this session
    private var screensViewedCount: Int = 0
    
    // User defaults keys
    private let onboardingCompletedKey = "sequence_onboarding_completed"
    private let userIdKey = "sequence_user_id"
    private let deviceIdKey = "sequence_device_id"
    
    // MARK: - Initialization
    
    private init() {
        // Generate or retrieve device ID
        if let storedDeviceId = UserDefaults.standard.string(forKey: deviceIdKey) {
            self.deviceId = storedDeviceId
        } else {
            let newDeviceId = UUID().uuidString
            UserDefaults.standard.set(newDeviceId, forKey: deviceIdKey)
            self.deviceId = newDeviceId
        }
        
        // Check if onboarding was previously completed
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        
        // Retrieve stored user ID if any
        self.userId = UserDefaults.standard.string(forKey: userIdKey)
    }
    
    // MARK: - Public Configuration
    
    /// Configure Sequence with your app credentials
    /// - Parameters:
    ///   - appId: Your Sequence App ID (found in dashboard)
    ///   - apiKey: Your Sequence API Key (found in dashboard settings)
    ///   - baseURL: Optional custom API URL (for self-hosted deployments)
    public func configure(appId: String, apiKey: String, baseURL: String? = nil) {
        self.appId = appId
        self.apiKey = apiKey
        if let baseURL = baseURL {
            self.baseURL = baseURL
        }
        
        // Start flush timer for batching events
        startFlushTimer()
        
        print("[Sequence] Configured with appId: \(appId)")
    }
    
    /// Set the current user ID for tracking
    /// Call this after user authentication
    /// - Parameter userId: Your app's user identifier
    public func identify(userId: String) {
        self.userId = userId
        UserDefaults.standard.set(userId, forKey: userIdKey)
        print("[Sequence] Identified user: \(userId)")
    }
    
    /// Reset user identification (e.g., on logout)
    public func reset() {
        self.userId = nil
        UserDefaults.standard.removeObject(forKey: userIdKey)
        
        // Generate new device ID for privacy
        let newDeviceId = UUID().uuidString
        UserDefaults.standard.set(newDeviceId, forKey: deviceIdKey)
        self.deviceId = newDeviceId
        
        // Reset onboarding state
        self.isOnboardingCompleted = false
        UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
        
        print("[Sequence] Reset user data")
    }
    
    /// Manually mark onboarding as completed
    /// (Automatically called when user finishes the flow)
    public func markOnboardingCompleted() {
        self.isOnboardingCompleted = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        track(eventType: .onboardingCompleted)
    }
    
    /// Reset onboarding state (useful for testing)
    public func resetOnboarding() {
        self.isOnboardingCompleted = false
        UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
    }
    
    // MARK: - Fetch Configuration
    
    /// Fetch the onboarding configuration from the server
    /// Call this when you're ready to show onboarding
    public func fetchConfig() async throws -> OnboardingConfig {
        guard let appId = appId, let apiKey = apiKey else {
            throw SequenceError.notConfigured
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let url = URL(string: "\(baseURL)/api/v1/config/\(appId)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SequenceError.networkError("Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw SequenceError.invalidCredentials
                }
                throw SequenceError.networkError("HTTP \(httpResponse.statusCode)")
            }
            
            // Debug: Print raw JSON response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔧 [Sequence SDK] Raw API response (first 2000 chars):")
                print(String(jsonString.prefix(2000)))
            }
            
            let decoder = JSONDecoder()
            // Note: Don't use .convertFromSnakeCase as the API returns camelCase for nested content
            // The top-level fields match Swift property names already
            let config: OnboardingConfig
            do {
                config = try decoder.decode(OnboardingConfig.self, from: data)
            } catch let DecodingError.keyNotFound(key, context) {
                print("🔴 [Sequence SDK] Decoding error - Key not found: '\(key.stringValue)' in \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                throw SequenceError.decodingError("Key not found: \(key.stringValue)")
            } catch let DecodingError.typeMismatch(type, context) {
                print("🔴 [Sequence SDK] Decoding error - Type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("🔴 [Sequence SDK] Debug description: \(context.debugDescription)")
                throw SequenceError.decodingError("Type mismatch at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            } catch let DecodingError.valueNotFound(type, context) {
                print("🔴 [Sequence SDK] Decoding error - Value not found: \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                throw SequenceError.decodingError("Value not found at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            } catch let DecodingError.dataCorrupted(context) {
                print("🔴 [Sequence SDK] Decoding error - Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("🔴 [Sequence SDK] Debug description: \(context.debugDescription)")
                throw SequenceError.decodingError("Data corrupted: \(context.debugDescription)")
            }
            
            await MainActor.run {
                self.config = config
                self.error = nil
            }
            
            // Debug logging for block positions
            print("🔧 [Sequence SDK] ====== CONFIG DEBUG ======")
            print("🔧 [Sequence SDK] Fetched config with \(config.screens.count) screens")
            for (screenIndex, screen) in config.screens.enumerated() {
                print("🔧 [Sequence SDK] Screen \(screenIndex): '\(screen.name)' (id: \(screen.id))")
                print("🔧 [Sequence SDK]   useBlocks: \(screen.content.useBlocks ?? false)")
                if let blocks = screen.content.blocks {
                    print("🔧 [Sequence SDK]   blocks count: \(blocks.count)")
                    for block in blocks {
                        if let pos = block.position {
                            print("🔧 [Sequence SDK]     - \(block.type) (id: \(block.id)): position=(\(pos.x), \(pos.y))")
                        } else {
                            print("🔧 [Sequence SDK]     - \(block.type) (id: \(block.id)): NO POSITION")
                        }
                        // For text blocks, print the content
                        if block.type == .text {
                            print("🔧 [Sequence SDK]       text: '\(block.content.text ?? "nil")'")
                        }
                    }
                } else {
                    print("🔧 [Sequence SDK]   blocks: nil")
                }
            }
            print("🔧 [Sequence SDK] ====== END CONFIG DEBUG ======")
            
            return config
            
        } catch let error as SequenceError {
            await MainActor.run { self.error = error }
            throw error
        } catch {
            let kitError = SequenceError.networkError(error.localizedDescription)
            await MainActor.run { self.error = kitError }
            throw kitError
        }
    }
    
    // MARK: - Event Tracking
    
    /// Track an onboarding event
    /// - Parameters:
    ///   - eventType: Type of event
    ///   - screenId: Optional screen ID for screen-related events
    ///   - properties: Optional additional properties
    public func track(
        eventType: EventType,
        screenId: String? = nil,
        properties: [String: Any]? = nil
    ) {
        let event = OnboardingEvent(
            eventType: eventType.rawValue,
            screenId: screenId,
            userId: userId ?? deviceId,
            deviceId: deviceId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            properties: properties
        )
        
        eventQueue.append(event)
        print("[Sequence] Tracked event: \(eventType.rawValue)")
        
        // Flush immediately if queue is getting large
        if eventQueue.count >= maxBatchSize {
            Task { await flush() }
        }
    }
    
    /// Track when a screen is viewed
    public func trackScreenViewed(screenId: String, screenName: String? = nil) {
        var props: [String: Any] = [:]
        if let name = screenName {
            props["screen_name"] = name
        }
        track(eventType: .screenViewed, screenId: screenId, properties: props.isEmpty ? nil : props)
    }

    /// Track when a screen is viewed for the first time (unique view)
    /// This is the key metric for conversion tracking - only counts once per user per screen
    public func trackScreenFirstViewed(screenId: String, screenName: String? = nil) {
        var props: [String: Any] = [:]
        if let name = screenName {
            props["screen_name"] = name
        }
        track(eventType: .screenFirstViewed, screenId: screenId, properties: props.isEmpty ? nil : props)
    }

    /// Track when a screen is completed
    public func trackScreenCompleted(screenId: String, screenName: String? = nil) {
        var props: [String: Any] = [:]
        if let name = screenName {
            props["screen_name"] = name
        }
        track(eventType: .screenCompleted, screenId: screenId, properties: props.isEmpty ? nil : props)
    }
    
    /// Track when a screen is skipped
    public func trackScreenSkipped(screenId: String, screenName: String? = nil) {
        var props: [String: Any] = [:]
        if let name = screenName {
            props["screen_name"] = name
        }
        track(eventType: .screenSkipped, screenId: screenId, properties: props.isEmpty ? nil : props)
    }
    
    /// Track when a button is tapped
    public func trackButtonTapped(screenId: String, buttonText: String) {
        track(eventType: .buttonTapped, screenId: screenId, properties: ["button_text": buttonText])
    }

    // MARK: - Session Management

    /// Start a new onboarding session
    /// Call this when the onboarding view appears
    public func startSession() {
        // Generate new session ID
        currentSessionId = UUID().uuidString
        sessionStartTime = Date()
        screensViewedCount = 0
        currentScreenId = nil
        currentScreenStartTime = nil

        // Device info will be included by the WebViewRenderer which has UIKit access
        let deviceModel = "iOS Device"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        print("[Sequence] Started session: \(currentSessionId ?? "nil")")

        // Track session start
        track(
            eventType: .sessionStarted,
            properties: [
                "session_id": currentSessionId ?? "",
                "device_model": deviceModel,
                "os_version": osVersion
            ]
        )

        // Also track onboarding_started for backward compatibility
        track(eventType: .onboardingStarted, properties: ["session_id": currentSessionId ?? ""])
    }

    /// End the current session
    /// - Parameter completed: Whether the user completed onboarding or dropped off
    internal func endSession(completed: Bool) {
        guard let sessionId = currentSessionId, let startTime = sessionStartTime else {
            return
        }

        let totalDuration = Int(Date().timeIntervalSince(startTime) * 1000) // ms

        if completed {
            track(
                eventType: .sessionCompleted,
                properties: [
                    "session_id": sessionId,
                    "total_duration_ms": totalDuration,
                    "screens_viewed": screensViewedCount,
                    "completed": true
                ]
            )
        } else {
            track(
                eventType: .sessionDroppedOff,
                properties: [
                    "session_id": sessionId,
                    "total_duration_ms": totalDuration,
                    "screens_viewed": screensViewedCount,
                    "last_screen_id": currentScreenId ?? "",
                    "completed": false
                ]
            )
        }

        print("[Sequence] Ended session: \(sessionId), completed: \(completed)")

        // Clear session state
        currentSessionId = nil
        sessionStartTime = nil
        currentScreenId = nil
        currentScreenStartTime = nil
        screensViewedCount = 0
    }

    // MARK: - Screen Time Tracking

    /// Track when user enters a screen (for time tracking)
    /// Called automatically by WebViewRenderer
    internal func trackScreenEnter(screenId: String, screenName: String?, isFirstView: Bool) {
        // If there's a previous screen, track its exit
        if let previousScreenId = currentScreenId, let previousStartTime = currentScreenStartTime {
            let duration = Int(Date().timeIntervalSince(previousStartTime) * 1000) // ms
            track(
                eventType: .screenCompleted,
                screenId: previousScreenId,
                properties: [
                    "session_id": currentSessionId ?? "",
                    "duration_ms": duration,
                    "next_screen_id": screenId
                ]
            )
            print("[Sequence] Screen \(previousScreenId) completed in \(duration)ms")
        }

        // Set new current screen
        currentScreenId = screenId
        currentScreenStartTime = Date()
        screensViewedCount += 1

        // Build properties
        var props: [String: Any] = [
            "session_id": currentSessionId ?? "",
            "screen_index": screensViewedCount - 1
        ]
        if let name = screenName {
            props["screen_name"] = name
        }

        // Track the appropriate view event
        if isFirstView {
            track(eventType: .screenFirstViewed, screenId: screenId, properties: props)
        } else {
            track(eventType: .screenViewed, screenId: screenId, properties: props)
        }
    }

    /// Track when user drops off on a specific screen (app backgrounded/closed)
    internal func trackScreenDropOff(reason: String) {
        guard let screenId = currentScreenId, let startTime = currentScreenStartTime else {
            return
        }

        let duration = Int(Date().timeIntervalSince(startTime) * 1000) // ms

        track(
            eventType: .screenDroppedOff,
            screenId: screenId,
            properties: [
                "session_id": currentSessionId ?? "",
                "duration_ms": duration,
                "drop_off_reason": reason
            ]
        )

        print("[Sequence] Screen \(screenId) dropped off after \(duration)ms, reason: \(reason)")
    }

    // MARK: - Event Flushing
    
    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { await self?.flush() }
        }
    }
    
    /// Manually flush all queued events to the server
    public func flush() async {
        guard !eventQueue.isEmpty else { return }
        guard let apiKey = apiKey else {
            print("[Sequence] Cannot flush - no API key configured")
            return
        }

        let eventsToSend = eventQueue
        eventQueue.removeAll()

        let urlString = "\(baseURL)/api/v1/events"
        guard let url = URL(string: urlString) else {
            print("[Sequence] Invalid URL: \(urlString)")
            eventQueue.insert(contentsOf: eventsToSend, at: 0)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = EventPayload(events: eventsToSend)

        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(payload)

            print("[Sequence] Flushing \(eventsToSend.count) events to \(urlString)")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[Sequence] ✅ Flushed \(eventsToSend.count) events successfully")
                } else {
                    // Re-queue events on failure
                    eventQueue.insert(contentsOf: eventsToSend, at: 0)
                    let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                    print("[Sequence] ❌ Failed to flush events - HTTP \(httpResponse.statusCode): \(responseBody)")
                }
            } else {
                eventQueue.insert(contentsOf: eventsToSend, at: 0)
                print("[Sequence] ❌ Failed to flush events - invalid response")
            }
        } catch {
            // Re-queue events on failure
            eventQueue.insert(contentsOf: eventsToSend, at: 0)
            print("[Sequence] ❌ Error flushing events: \(error.localizedDescription)")
        }
    }
    
    deinit {
        flushTimer?.invalidate()
    }

    // MARK: - Native Action Result Callbacks

    /// Send a success result back to the WebView
    /// Call this after successfully handling an auth or permission request
    public func sendSuccessResult(data: [String: Any]? = nil) {
        let result = NativeActionResult.success(data: data)
        webViewResultCallback?(result)
    }

    /// Send a failure result back to the WebView
    /// Call this when an auth or permission request fails
    public func sendFailureResult(error: String? = nil) {
        let result = NativeActionResult.failure(error: error)
        webViewResultCallback?(result)
    }

    /// Send a cancelled result back to the WebView
    /// Call this when the user cancels an auth or permission request
    public func sendCancelledResult() {
        let result = NativeActionResult.cancelled
        webViewResultCallback?(result)
    }

    // MARK: - Auth Backend Verification

    /// Result from backend auth verification
    public struct AuthVerifyResult {
        public let isNewUser: Bool
        public let userId: String?
    }

    /// Legacy type alias for backward compatibility
    public typealias AppleAuthVerifyResult = AuthVerifyResult

    /// Verify Apple auth credential with the backend
    /// This checks if the user is new or returning and creates/updates the user record
    /// - Parameter credential: The Apple auth credential to verify
    /// - Returns: Result containing isNewUser flag
    public func verifyAppleAuth(credential: AppleAuthCredential) async throws -> AppleAuthVerifyResult {
        guard let apiKey = apiKey else {
            throw SequenceError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/apple")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        var body: [String: Any] = [
            "user_identifier": credential.userIdentifier
        ]

        if let identityToken = credential.identityTokenString {
            body["identity_token"] = identityToken
        }

        if let email = credential.email {
            body["email"] = email
        }

        if let givenName = credential.fullName?.givenName {
            body["given_name"] = givenName
        }

        if let familyName = credential.fullName?.familyName {
            body["family_name"] = familyName
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[Sequence] Verifying Apple auth with backend...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SequenceError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[Sequence] Apple auth verification failed: HTTP \(httpResponse.statusCode) - \(responseBody)")
            throw SequenceError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SequenceError.decodingError("Invalid JSON response")
        }

        let isNewUser = json["is_new_user"] as? Bool ?? true
        let userId = json["user_id"] as? String

        print("[Sequence] Apple auth verified - isNewUser: \(isNewUser)")

        return AuthVerifyResult(isNewUser: isNewUser, userId: userId)
    }

    // MARK: - Google Auth Backend Verification

    /// Verify Google auth credential with the backend
    /// This checks if the user is new or returning and creates/updates the user record
    /// - Parameter credential: The Google auth credential to verify
    /// - Returns: Result containing isNewUser flag
    public func verifyGoogleAuth(credential: GoogleAuthCredential) async throws -> AuthVerifyResult {
        guard let apiKey = apiKey else {
            throw SequenceError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/google")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        var body: [String: Any] = [
            "id_token": credential.idToken
        ]

        if let email = credential.email {
            body["email"] = email
        }

        // Parse display name into given/family name if available
        if let displayName = credential.displayName {
            let nameParts = displayName.split(separator: " ", maxSplits: 1)
            if nameParts.count > 0 {
                body["given_name"] = String(nameParts[0])
            }
            if nameParts.count > 1 {
                body["family_name"] = String(nameParts[1])
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[Sequence] Verifying Google auth with backend...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SequenceError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[Sequence] Google auth verification failed: HTTP \(httpResponse.statusCode) - \(responseBody)")
            throw SequenceError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SequenceError.decodingError("Invalid JSON response")
        }

        let isNewUser = json["is_new_user"] as? Bool ?? true
        let userId = json["user_id"] as? String

        print("[Sequence] Google auth verified - isNewUser: \(isNewUser)")

        return AuthVerifyResult(isNewUser: isNewUser, userId: userId)
    }

    /// Complete Google sign-in flow after app handles Google SDK authentication
    /// This verifies with the backend and sends the result to the WebView
    /// - Parameter credential: The Google auth credential
    public func completeGoogleSignIn(credential: GoogleAuthCredential) async {
        do {
            let result = try await verifyGoogleAuth(credential: credential)
            sendSuccessResult(data: ["isNewUser": result.isNewUser, "userId": result.userId as Any])
        } catch {
            print("[Sequence] Google sign-in completion failed: \(error)")
            sendFailureResult(error: error.localizedDescription)
        }
    }

    // MARK: - Email Auth Backend Verification

    /// Verify email auth with the backend
    /// Call this after your app has verified the user's email (via password, magic link, OTP, etc.)
    /// - Parameters:
    ///   - email: The verified email address
    ///   - givenName: Optional first name
    ///   - familyName: Optional last name
    /// - Returns: Result containing isNewUser flag
    public func verifyEmailAuth(email: String, givenName: String? = nil, familyName: String? = nil) async throws -> AuthVerifyResult {
        guard let apiKey = apiKey else {
            throw SequenceError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/v1/auth/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        var body: [String: Any] = [
            "email": email
        ]

        if let givenName = givenName {
            body["given_name"] = givenName
        }

        if let familyName = familyName {
            body["family_name"] = familyName
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[Sequence] Verifying email auth with backend...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SequenceError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[Sequence] Email auth verification failed: HTTP \(httpResponse.statusCode) - \(responseBody)")
            throw SequenceError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SequenceError.decodingError("Invalid JSON response")
        }

        let isNewUser = json["is_new_user"] as? Bool ?? true
        let userId = json["user_id"] as? String

        print("[Sequence] Email auth verified - isNewUser: \(isNewUser)")

        return AuthVerifyResult(isNewUser: isNewUser, userId: userId)
    }
}

// MARK: - Native Action Result

/// Result type sent back to WebView for bidirectional communication
public enum NativeActionResult {
    case success(data: [String: Any]?)
    case failure(error: String?)
    case cancelled

    var jsonString: String {
        switch self {
        case .success(let data):
            if let data = data,
               let jsonData = try? JSONSerialization.data(withJSONObject: data),
               let dataString = String(data: jsonData, encoding: .utf8) {
                return "{ \"status\": \"success\", \"data\": \(dataString) }"
            }
            return "{ \"status\": \"success\" }"
        case .failure(let error):
            if let error = error {
                return "{ \"status\": \"failure\", \"error\": \"\(error.replacingOccurrences(of: "\"", with: "\\\""))\" }"
            }
            return "{ \"status\": \"failure\" }"
        case .cancelled:
            return "{ \"status\": \"cancelled\" }"
        }
    }
}

// MARK: - Event Payload for API

private struct EventPayload: Encodable {
    let events: [OnboardingEvent]
}

