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
    
    /// Current experiment info (if user is part of an A/B test)
    private var currentExperiment: ExperimentInfo?
    
    // User defaults keys
    private let onboardingCompletedKey = "sequence_onboarding_completed"
    private let userIdKey = "sequence_user_id"
    private let deviceIdKey = "sequence_device_id"
    private let firstViewedScreensKey = "sequence_first_viewed_screens" // Set of screen IDs that have been viewed
    
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
        
        // Reset first viewed screens (new user/device = fresh start)
        UserDefaults.standard.removeObject(forKey: firstViewedScreensKey)
        
        print("[Sequence] Reset user data")
    }
    
    /// Set experiment info for event tracking (used by WebView flows)
    /// - Parameters:
    ///   - experimentId: The experiment ID
    ///   - variantId: The variant ID the user is assigned to
    ///   - variantName: The variant name for logging
    public func setExperimentInfo(experimentId: String, variantId: String, variantName: String) {
        self.currentExperiment = ExperimentInfo(id: experimentId, variantId: variantId, variantName: variantName)
        print("[Sequence] 🧪 Set experiment info: '\(experimentId)' variant '\(variantName)'")
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
    /// - Parameter session: Optional URLSession for dependency injection (used in testing)
    public func fetchConfig(session: URLSession = .shared) async throws -> OnboardingConfig {
        guard let appId = appId, let apiKey = apiKey else {
            throw SequenceError.notConfigured
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let url = URL(string: "\(baseURL)/api/v1/config/\(appId)")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(deviceId, forHTTPHeaderField: "x-device-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Measure fetch time
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await session.data(for: request)
            
            let fetchTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("[Sequence] ⏱️ Config fetched in \(String(format: "%.0f", fetchTime))ms")
            
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
            let config = try decoder.decode(OnboardingConfig.self, from: data)
            
            await MainActor.run {
                self.config = config
                self.error = nil
                
                // Store experiment info if present (for including in events)
                if let experiment = config.experiment {
                    self.currentExperiment = experiment
                    print("[Sequence] 🧪 Assigned to experiment '\(experiment.id)' variant '\(experiment.variantName)'")
                } else {
                    self.currentExperiment = nil
                }
            }
            
            // Preload fonts used in the config
            preloadFontsFromConfig(config)
            
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
                        // For text blocks, print typography info
                        if block.type == .text {
                            print("🔧 [Sequence SDK]       text: '\(block.content.text?.prefix(30) ?? "nil")...'")
                            print("🔧 [Sequence SDK]       fontFamily: \(block.content.fontFamily ?? "nil")")
                            print("🔧 [Sequence SDK]       fontSize: \(block.content.fontSizeValue.map { String(format: "%.0f", $0) } ?? "nil")")
                            print("🔧 [Sequence SDK]       fontWeight: \(block.content.fontWeight ?? "nil")")
                            print("🔧 [Sequence SDK]       variant: \(block.content.variant ?? "nil")")
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
    
    /// Preload all fonts used in the config so they're ready when screens are displayed
    private func preloadFontsFromConfig(_ config: OnboardingConfig) {
        var fontNames: Set<String> = []
        
        // Collect all font families used in the config
        for screen in config.screens {
            if let blocks = screen.content.blocks {
                for block in blocks {
                    // Text blocks
                    if let fontFamily = block.content.fontFamily, !fontFamily.isEmpty {
                        fontNames.insert(fontFamily)
                    }
                }
            }
        }
        
        guard !fontNames.isEmpty else { return }
        
        print("🔤 [Sequence SDK] Preloading \(fontNames.count) fonts: \(fontNames.joined(separator: ", "))")
        FontManager.shared.preloadFonts(Array(fontNames))
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
            properties: properties,
            experimentId: currentExperiment?.id,
            variantId: currentExperiment?.variantId
        )
        
        eventQueue.append(event)
        
        if let exp = currentExperiment {
            print("[Sequence] Tracked event: \(eventType.rawValue) (experiment: \(exp.variantName))")
        } else {
            print("[Sequence] Tracked event: \(eventType.rawValue)")
        }
        
        // Flush immediately if queue is getting large
        if eventQueue.count >= maxBatchSize {
            Task { await flush() }
        }
    }
    
    /// Track when a screen is viewed (all views)
    public func trackScreenViewed(screenId: String, screenName: String? = nil) {
        var props: [String: Any] = [:]
        if let name = screenName {
            props["screen_name"] = name
        }
        track(eventType: .screenViewed, screenId: screenId, properties: props.isEmpty ? nil : props)
    }
    
    /// Track when a screen is viewed for the first time (one per user per screen, persistent across sessions)
    /// Uses UserDefaults to deduplicate - only tracks once per screen per user/device ever
    /// This gives accurate metrics: "How many unique users have seen this screen?"
    public func trackScreenFirstViewed(screenId: String, screenName: String? = nil) {
        // Check if we've already tracked first view for this screen (persistent across sessions)
        var viewedScreens = Set<String>(UserDefaults.standard.stringArray(forKey: firstViewedScreensKey) ?? [])
        
        // If already viewed before (in any session), skip tracking
        if viewedScreens.contains(screenId) {
            return
        }
        
        // Mark as viewed (persists across app sessions)
        viewedScreens.insert(screenId)
        UserDefaults.standard.set(Array(viewedScreens), forKey: firstViewedScreensKey)
        
        // Track the first view event
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
    
    /// Track when a user drops off (exits without completing a screen)
    public func trackScreenDroppedOff(screenId: String, screenName: String? = nil, reason: String? = nil) {
        var props: [String: Any] = [:]
        if let name = screenName {
            props["screen_name"] = name
        }
        if let reason = reason {
            props["drop_off_reason"] = reason
        }
        track(eventType: .screenDroppedOff, screenId: screenId, properties: props.isEmpty ? nil : props)
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
    
    /// Force flush events immediately (used for critical events like drop-offs)
    /// This uses a synchronous URLSession data task to ensure events are sent before app termination
    public func forceFlush() {
        guard !eventQueue.isEmpty else { return }
        guard let apiKey = apiKey else { return }
        
        let eventsToSend = eventQueue
        eventQueue.removeAll()
        
        let url = URL(string: "\(baseURL)/api/v1/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0 // Short timeout for quick flush
        
        let payload = EventPayload(events: eventsToSend)
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(payload)
            
            // Use semaphore to wait for completion (synchronous)
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            
            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    success = true
                    print("[Sequence] Force flushed \(eventsToSend.count) events")
                } else {
                    print("[Sequence] Failed to force flush events")
                }
                semaphore.signal()
            }
            
            task.resume()
            _ = semaphore.wait(timeout: .now() + 5.0) // Wait up to 5 seconds
            
            if !success {
                // Re-queue on failure
                eventQueue.insert(contentsOf: eventsToSend, at: 0)
            }
        } catch {
            // Re-queue on failure
            eventQueue.insert(contentsOf: eventsToSend, at: 0)
            print("[Sequence] Error force flushing events: \(error)")
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

