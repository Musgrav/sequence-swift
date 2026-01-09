// Sequence Swift SDK
// https://github.com/your-repo/sequence

import Foundation
import SwiftUI
import Combine

/// Main entry point for Sequence SDK
/// Initialize once in your app (e.g., in AppDelegate or @main App)
@MainActor
public final class Sequence: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance of Sequence
    public static let shared = Sequence()
    
    // MARK: - Published Properties
    
    /// Current onboarding configuration fetched from server
    @Published public private(set) var config: OnboardingConfig?
    
    /// Whether the SDK is currently fetching configuration
    @Published public private(set) var isLoading = false
    
    /// Whether onboarding has been completed by this user
    @Published public private(set) var isOnboardingCompleted = false
    
    /// Current error if any
    @Published public private(set) var error: SequenceError?
    
    // MARK: - Private Properties
    
    private var appId: String?
    private var apiKey: String?
    private var baseURL: String = "https://your-domain.com" // Default, override in configure
    private var userId: String?
    private var deviceId: String
    private var eventQueue: [OnboardingEvent] = []
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval = 10.0 // Flush events every 10 seconds
    private let maxBatchSize = 20
    private var cancellables = Set<AnyCancellable>()
    
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
            
            let decoder = JSONDecoder()
            // Note: Don't use .convertFromSnakeCase as the API returns camelCase for nested content
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

            print("[Sequence] Fetched config with \(config.screens.count) screens")
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
            userId: userId ?? "anonymous",
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
        guard let apiKey = apiKey else { return }
        
        let eventsToSend = eventQueue
        eventQueue.removeAll()
        
        let url = URL(string: "\(baseURL)/api/v1/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = EventPayload(events: eventsToSend)
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[Sequence] Flushed \(eventsToSend.count) events")
            } else {
                // Re-queue events on failure
                eventQueue.insert(contentsOf: eventsToSend, at: 0)
                print("[Sequence] Failed to flush events, re-queued")
            }
        } catch {
            // Re-queue events on failure
            eventQueue.insert(contentsOf: eventsToSend, at: 0)
            print("[Sequence] Error flushing events: \(error)")
        }
    }
    
    deinit {
        flushTimer?.invalidate()
    }
}

// MARK: - Event Payload for API

private struct EventPayload: Encodable {
    let events: [OnboardingEvent]
}

