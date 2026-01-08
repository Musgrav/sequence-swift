// WebView-based Onboarding View
// Uses WKWebView to render onboarding flows for pixel-perfect WYSIWYG rendering
// The same HTML/CSS/JS used in the editor runs on the device

import SwiftUI
import WebKit
import OSLog
import UIKit

private let webLogger = Logger(subsystem: "com.sequence.sdk", category: "WebOnboardingView")

// MARK: - WebView Onboarding View

/// WebView-based onboarding view that renders flows with pixel-perfect accuracy
/// This approach loads the same HTML/CSS used in the web editor for true WYSIWYG
public struct WebOnboardingView: View {
    @StateObject private var viewModel = WebOnboardingViewModel()
    
    /// Called when onboarding is completed or dismissed
    public var onComplete: () -> Void
    
    /// Optional callback for custom native actions (auth, permissions, etc.)
    public var onCustomAction: ((String) -> Void)?
    
    /// Optional callback when a native screen is requested
    public var onNativeScreen: ((String) -> AnyView)?
    
    public init(
        onComplete: @escaping () -> Void,
        onCustomAction: ((String) -> Void)? = nil,
        onNativeScreen: ((String) -> AnyView)? = nil
    ) {
        self.onComplete = onComplete
        self.onCustomAction = onCustomAction
        self.onNativeScreen = onNativeScreen
    }
    
    public var body: some View {
        ZStack {
            // Base background to prevent white flash
            Color(hex: "#0f172a")
                .ignoresSafeArea(.all, edges: .all)
            
            if viewModel.isLoading {
                LoadingStateView()
            } else if let error = viewModel.error {
                ErrorStateView(error: error) {
                    Task { await viewModel.loadFlow() }
                }
            } else if viewModel.showNativeScreen, let screenId = viewModel.currentNativeScreenId {
                // Show native screen if requested
                if let onNativeScreen = onNativeScreen {
                    onNativeScreen(screenId)
                } else {
                    // Fallback if no native screen handler
                    Text("Native screen: \(screenId)")
                        .foregroundColor(.white)
                }
            } else if let htmlURL = viewModel.flowHTMLURL {
                // Main WebView content
                SequenceWebView(
                    url: htmlURL,
                    viewModel: viewModel,
                    onComplete: onComplete,
                    onCustomAction: onCustomAction
                )
                .ignoresSafeArea(.all, edges: .all)
            }
        }
        .task {
            await viewModel.loadFlow()
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                onComplete()
            }
        }
    }
}

// MARK: - WebView ViewModel

@MainActor
class WebOnboardingViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var error: SequenceError?
    @Published var flowHTMLURL: URL?
    @Published var isCompleted = false
    @Published var showNativeScreen = false
    @Published var currentNativeScreenId: String?
    
    /// Load the flow HTML from the server
    func loadFlow() async {
        isLoading = true
        error = nil
        
        guard let appId = getAppId() else {
            error = .notConfigured
            isLoading = false
            print("❌ [WebOnboarding] SDK not configured - missing appId")
            return
        }
        
        // Build the URL to the HTML bundle
        // The server renders a self-contained HTML page with all styles/scripts
        let baseURL = getBaseURL()
        
        // Add API key as query parameter so it works with WebView
        // (WebView headers can be unreliable)
        var urlComponents = URLComponents(string: "\(baseURL)/render/\(appId)")
        
        if let apiKey = getApiKey() {
            urlComponents?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }
        
        guard let url = urlComponents?.url else {
            error = .networkError("Invalid URL")
            isLoading = false
            print("❌ [WebOnboarding] Invalid URL constructed")
            return
        }
        
        let htmlURLString = url.absoluteString
        webLogger.info("Loading flow HTML from: \(htmlURLString)")
        print("🌐 [WebOnboarding] Loading flow HTML from: \(htmlURLString)")
        
        // Skip validation - let the WebView load directly
        // This avoids duplicate requests and header issues
        flowHTMLURL = url
        isLoading = false
    }
    
    /// Handle messages from JavaScript
    func handleJSMessage(_ message: JSMessage) {
        webLogger.info("Received JS message: \(message.action)")
        
        switch message.action {
        case "next":
            // Navigate to next screen (handled by web)
            Sequence.shared.track(eventType: .screenCompleted, screenId: message.screenId)
            
        case "previous":
            // Navigate to previous screen (handled by web)
            break
            
        case "complete":
            // Mark onboarding as complete
            // Set experiment info if present (for WebView flows)
            if let experimentId = message.data?["experimentId"] as? String,
               let variantId = message.data?["variantId"] as? String {
                Sequence.shared.setExperimentInfo(experimentId: experimentId, variantId: variantId, variantName: variantId)
            }
            // Extract collected data if present
            if let collectedData = message.data?["collectedData"] as? [String: Any] {
                handleCollectedData(collectedData)
            }
            // Track onboarding completed event (includes experiment info)
            Sequence.shared.track(eventType: .onboardingCompleted)
            // Notify the SDK that onboarding is complete
            Sequence.shared.markOnboardingCompleted()
            isCompleted = true
            
        case "screen":
            // Navigate to specific screen (handled by web)
            break
            
        case "native":
            // Show a native screen
            if let screenId = message.data?["screenId"] as? String {
                currentNativeScreenId = screenId
                showNativeScreen = true
            }
            
        case "custom":
            // Trigger custom action
            if let identifier = message.data?["identifier"] as? String {
                // This will be handled by the parent view
                NotificationCenter.default.post(
                    name: .sequenceCustomAction,
                    object: nil,
                    userInfo: ["identifier": identifier]
                )
            }
            
        case "track":
            // Track an event
            if let eventType = message.data?["eventType"] as? String {
                let event = EventType(rawValue: eventType) ?? .buttonTapped
                Sequence.shared.track(eventType: event, screenId: message.screenId)
            }
            // Extract collected data if present
            if let collectedData = message.data?["collectedData"] as? [String: Any] {
                handleCollectedData(collectedData)
            }
            
        case "onboardingStarted":
            // Track onboarding started event
            // Set experiment info if present (for WebView flows)
            if let experimentId = message.data?["experimentId"] as? String,
               let variantId = message.data?["variantId"] as? String {
                Sequence.shared.setExperimentInfo(experimentId: experimentId, variantId: variantId, variantName: variantId)
            }
            Sequence.shared.track(eventType: .onboardingStarted)
            
        case "screenViewed":
            // Track screen view (all views)
            // Set experiment info if present (for WebView flows)
            if let experimentId = message.data?["experimentId"] as? String,
               let variantId = message.data?["variantId"] as? String {
                Sequence.shared.setExperimentInfo(experimentId: experimentId, variantId: variantId, variantName: variantId)
            }
            if let screenId = message.screenId {
                let screenName = message.data?["screenName"] as? String
                Sequence.shared.trackScreenViewed(screenId: screenId, screenName: screenName)
            }
            // Extract collected data if present
            if let collectedData = message.data?["collectedData"] as? [String: Any] {
                handleCollectedData(collectedData)
            }
            
        case "screenFirstViewed":
            // Track first screen view (deduplicated)
            // Set experiment info if present (for WebView flows)
            if let experimentId = message.data?["experimentId"] as? String,
               let variantId = message.data?["variantId"] as? String {
                Sequence.shared.setExperimentInfo(experimentId: experimentId, variantId: variantId, variantName: variantId)
            }
            if let screenId = message.screenId {
                let screenName = message.data?["screenName"] as? String
                Sequence.shared.trackScreenFirstViewed(screenId: screenId, screenName: screenName)
            }
            // Extract collected data if present
            if let collectedData = message.data?["collectedData"] as? [String: Any] {
                handleCollectedData(collectedData)
            }
            
        case "dataUpdate":
            // Handle data updates from input fields
            if let collectedData = message.data?["collectedData"] as? [String: Any] {
                handleCollectedData(collectedData)
            }
            
        case "screenDroppedOff":
            // Track drop-off when user leaves without completing screen
            // Set experiment info if present (for WebView flows)
            if let experimentId = message.data?["experimentId"] as? String,
               let variantId = message.data?["variantId"] as? String {
                Sequence.shared.setExperimentInfo(experimentId: experimentId, variantId: variantId, variantName: variantId)
            }
            if let screenId = message.screenId {
                let screenName = message.data?["screenName"] as? String
                let reason = message.data?["reason"] as? String ?? "unknown"
                Sequence.shared.trackScreenDroppedOff(screenId: screenId, screenName: screenName, reason: reason)
            }
            // Extract collected data if present
            if let collectedData = message.data?["collectedData"] as? [String: Any] {
                handleCollectedData(collectedData)
            }
            
        case "error":
            // Handle error from web
            if let errorMessage = message.data?["message"] as? String {
                webLogger.error("WebView error: \(errorMessage)")
            }

        case "haptic":
            // Trigger haptic feedback
            if let intensity = message.data?["intensity"] as? String {
                let style: UIImpactFeedbackGenerator.FeedbackStyle
                switch intensity {
                case "light":
                    style = .light
                case "heavy":
                    style = .heavy
                default: // "medium"
                    style = .medium
                }
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.prepare()
                generator.impactOccurred()
            }

        default:
            webLogger.warning("Unknown JS message action: \(message.action)")
        }
    }
    
    /// Dismiss native screen and return to web flow
    func dismissNativeScreen() {
        showNativeScreen = false
        currentNativeScreenId = nil
    }
    
    /// Handle collected data from input fields
    /// This data can be used by the app or stored for later use
    private func handleCollectedData(_ data: [String: Any]) {
        webLogger.info("Received collected data: \(data.keys.joined(separator: ", "))")
        print("📊 [WebOnboarding] Collected data: \(data)")
        
        // Post notification so the app can access the collected data
        NotificationCenter.default.post(
            name: .sequenceCollectedData,
            object: nil,
            userInfo: ["data": data]
        )
    }
    
    // MARK: - Private Helpers
    
    private func getAppId() -> String? {
        // Access the configured app ID from Sequence
        // Using Mirror to access private property
        let mirror = Mirror(reflecting: Sequence.shared)
        for child in mirror.children {
            if child.label == "appId", let appId = child.value as? String {
                return appId
            }
        }
        return nil
    }
    
    private func getApiKey() -> String? {
        let mirror = Mirror(reflecting: Sequence.shared)
        for child in mirror.children {
            if child.label == "apiKey", let apiKey = child.value as? String {
                return apiKey
            }
        }
        return nil
    }
    
    private func getBaseURL() -> String {
        let mirror = Mirror(reflecting: Sequence.shared)
        for child in mirror.children {
            if child.label == "baseURL", let baseURL = child.value as? String {
                return baseURL
            }
        }
        return "https://your-domain.com"
    }
}

// MARK: - JavaScript Message

struct JSMessage {
    let action: String
    let screenId: String?
    let data: [String: Any]?
    
    init?(from dict: [String: Any]) {
        guard let action = dict["action"] as? String else { return nil }
        self.action = action
        self.screenId = dict["screenId"] as? String
        self.data = dict["data"] as? [String: Any]
    }
}

// MARK: - WKWebView Wrapper

struct SequenceWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var viewModel: WebOnboardingViewModel
    let onComplete: () -> Void
    let onCustomAction: ((String) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable JavaScript
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Add the message handler for Swift <-> JS communication
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "sequence")
        config.userContentController = contentController
        
        // Allow inline media playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // CRITICAL: Prevent scroll view from adding safe area insets
        // This allows web content to extend into safe areas (edge-to-edge)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Disable zoom
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        
        // Load the flow HTML
        // API key is already in the URL as a query parameter
        let request = URLRequest(url: url)
        print("🌐 [WebView] Loading URL: \(url.absoluteString)")
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed - WebView handles its own state
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onComplete: onComplete, onCustomAction: onCustomAction)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let viewModel: WebOnboardingViewModel
        let onComplete: () -> Void
        let onCustomAction: ((String) -> Void)?
        
        init(viewModel: WebOnboardingViewModel, onComplete: @escaping () -> Void, onCustomAction: ((String) -> Void)?) {
            self.viewModel = viewModel
            self.onComplete = onComplete
            self.onCustomAction = onCustomAction
        }
        
        // MARK: WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "sequence" else { return }
            
            guard let body = message.body as? [String: Any],
                  let jsMessage = JSMessage(from: body) else {
                webLogger.warning("Invalid message format from JS")
                return
            }
            
            Task { @MainActor in
                viewModel.handleJSMessage(jsMessage)
                
                // Handle custom actions through the callback
                if jsMessage.action == "custom",
                   let identifier = jsMessage.data?["identifier"] as? String {
                    onCustomAction?(identifier)
                }
                
                // Handle completion
                if jsMessage.action == "complete" {
                    onComplete()
                }
            }
        }
        
        // MARK: WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webLogger.info("WebView finished loading")
            print("WebView finished loading")
            
            // Inject CSS to ensure proper edge-to-edge rendering
            // Using !important to override any conflicting styles
            let css = """
            ::-webkit-scrollbar { display: none !important; }
            html, body {
                margin: 0 !important;
                padding: 0 !important;
                width: 100% !important;
                height: 100% !important;
                min-height: 100% !important;
                overflow: hidden !important;
                -webkit-user-select: none;
                -webkit-touch-callout: none;
                -webkit-tap-highlight-color: transparent;
            }
            #__next {
                min-height: 100% !important;
            }
            """
            let js = "var style = document.createElement('style'); style.textContent = `\(css)`; document.head.appendChild(style);"
            webView.evaluateJavaScript(js)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webLogger.error("WebView navigation failed: \(error.localizedDescription)")
            Task { @MainActor in
                viewModel.error = .networkError(error.localizedDescription)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webLogger.error("WebView provisional navigation failed: \(error.localizedDescription)")
            Task { @MainActor in
                viewModel.error = .networkError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Supporting Views

private struct LoadingStateView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0f172a")
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
        .ignoresSafeArea(.all, edges: .all)
    }
}

private struct ErrorStateView: View {
    let error: SequenceError
    let onRetry: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#0f172a")
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Unable to load onboarding")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#10b981"))
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .ignoresSafeArea(.all, edges: .all)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sequenceCustomAction = Notification.Name("sequenceCustomAction")
    static let sequenceCollectedData = Notification.Name("sequenceCollectedData")
}

// MARK: - Preview

#if DEBUG
struct WebOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        WebOnboardingView(onComplete: {})
    }
}
#endif

