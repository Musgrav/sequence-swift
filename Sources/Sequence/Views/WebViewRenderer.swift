// WebView-based WYSIWYG Renderer for Sequence
// Loads the same web renderer as the editor for pixel-perfect rendering

#if canImport(UIKit)
import SwiftUI
import WebKit
import UIKit

/// Messages sent from JavaScript to Swift
enum WebViewMessage: String {
    case buttonTap = "buttonTap"
    case screenChange = "screenChange"
    case onboardingComplete = "onboardingComplete"
    case dataCollected = "dataCollected"
    case ready = "ready"
    case error = "error"
}

/// SwiftUI wrapper for WKWebView that renders onboarding flows
public struct WebViewRenderer: UIViewRepresentable {
    let appId: String
    let baseURL: String
    let onComplete: () -> Void
    let onScreenChange: ((String) -> Void)?
    let onDataCollected: (([String: Any]) -> Void)?

    @Binding var isLoading: Bool
    @Binding var error: String?

    public init(
        appId: String,
        baseURL: String,
        isLoading: Binding<Bool>,
        error: Binding<String?>,
        onComplete: @escaping () -> Void,
        onScreenChange: ((String) -> Void)? = nil,
        onDataCollected: (([String: Any]) -> Void)? = nil
    ) {
        self.appId = appId
        self.baseURL = baseURL
        self._isLoading = isLoading
        self._error = error
        self.onComplete = onComplete
        self.onScreenChange = onScreenChange
        self.onDataCollected = onDataCollected
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        // Configure WebView for optimal rendering
        let config = WKWebViewConfiguration()

        // Set up JavaScript message handler
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "sequenceHandler")
        config.userContentController = contentController

        // Enable JavaScript
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Get the screen dimensions to inject early
        // This provides accurate dimensions before the WebView is laid out
        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale

        // Inject viewport dimensions at document START so they're available immediately
        // This prevents the race condition where FlowRenderer calculates scale before we inject
        let earlyViewportScript = """
            window.sequenceViewport = {
                width: \(screenBounds.width),
                height: \(screenBounds.height),
                scale: \(screenScale),
                isEarlyEstimate: true
            };
            console.log('[Sequence] Early viewport injected:', window.sequenceViewport);
        """
        let earlyScript = WKUserScript(source: earlyViewportScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(earlyScript)

        // Disable zoom for consistent rendering and enable full-screen coverage
        let viewportScript = """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
            document.getElementsByTagName('head')[0].appendChild(meta);
        """
        let script = WKUserScript(source: viewportScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(script)

        // Inject the JavaScript bridge for communication
        let bridgeScript = WKUserScript(
            source: Self.jsBridgeCode,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear

        // CRITICAL: Prevent scroll view from adding safe area insets
        // This allows web content to extend into safe areas (edge-to-edge)
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Disable caching for development
        #if DEBUG
        webView.configuration.websiteDataStore = .nonPersistent()
        #endif

        // Store coordinator reference for later use
        context.coordinator.webView = webView

        // Load the render URL
        let renderURL = "\(baseURL)/render/\(appId)"
        print("[Sequence WebView] Loading URL: \(renderURL)")

        if let url = URL(string: renderURL) {
            var request = URLRequest(url: url)
            // Disable caching
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            webView.load(request)
        }

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Inject actual WebView dimensions into the page
        // This ensures the web content can scale to the full WebView size
        // including safe areas that might not be reported by window.innerWidth/Height
        let bounds = webView.bounds
        if bounds.width > 0 && bounds.height > 0 {
            let script = """
                window.sequenceViewport = {
                    width: \(bounds.width),
                    height: \(bounds.height)
                };
                // Dispatch event so FlowRenderer can use these dimensions
                window.dispatchEvent(new CustomEvent('sequenceViewportReady', {
                    detail: window.sequenceViewport
                }));
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    /// JavaScript bridge code injected into the WebView
    /// This allows the web renderer to communicate with native Swift
    private static var jsBridgeCode: String {
        """
        (function() {
            // Create the Sequence bridge object
            window.SequenceBridge = {
                // Called when a button is tapped
                onButtonTap: function(action, screenId, buttonText) {
                    window.webkit.messageHandlers.sequenceHandler.postMessage({
                        type: 'buttonTap',
                        action: action,
                        screenId: screenId,
                        buttonText: buttonText
                    });
                },

                // Called when screen changes
                onScreenChange: function(screenId, screenName) {
                    window.webkit.messageHandlers.sequenceHandler.postMessage({
                        type: 'screenChange',
                        screenId: screenId,
                        screenName: screenName
                    });
                },

                // Called when onboarding is complete
                onComplete: function(collectedData) {
                    window.webkit.messageHandlers.sequenceHandler.postMessage({
                        type: 'onboardingComplete',
                        collectedData: collectedData || {}
                    });
                },

                // Called when data is collected (form inputs, checklist selections)
                onDataCollected: function(data) {
                    window.webkit.messageHandlers.sequenceHandler.postMessage({
                        type: 'dataCollected',
                        data: data
                    });
                },

                // Called when the renderer is ready
                onReady: function() {
                    window.webkit.messageHandlers.sequenceHandler.postMessage({
                        type: 'ready'
                    });
                },

                // Called on error
                onError: function(message) {
                    window.webkit.messageHandlers.sequenceHandler.postMessage({
                        type: 'error',
                        message: message
                    });
                }
            };

            console.log('[SequenceBridge] Initialized');
        })();
        """
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewRenderer
        weak var webView: WKWebView?
        private var backgroundObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
        private var hasInjectedAccurateViewport = false

        init(_ parent: WebViewRenderer) {
            self.parent = parent
            super.init()
            setupLifecycleObservers()
        }

        deinit {
            removeLifecycleObservers()
        }

        // MARK: - App Lifecycle Observers (for drop-off detection)

        private func setupLifecycleObservers() {
            // Track when app goes to background - potential drop-off
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppWillResignActive()
            }

            // Track when app returns to foreground
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
        }

        private func removeLifecycleObservers() {
            if let observer = backgroundObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = foregroundObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func handleAppWillResignActive() {
            // Only track drop-off if we have an active session AND user has viewed at least one screen
            guard Sequence.shared.currentSessionId != nil,
                  Sequence.shared.currentScreenId != nil else {
                print("[Sequence WebView] App going to background - no active screen, skipping drop-off tracking")
                return
            }

            // User is leaving the app while onboarding - track drop-off
            print("[Sequence WebView] App going to background - tracking drop-off on screen: \(Sequence.shared.currentScreenId ?? "unknown")")
            Sequence.shared.trackScreenDropOff(reason: "app_backgrounded")

            // Flush events immediately so we don't lose them
            Task {
                await Sequence.shared.flush()
            }
        }

        private func handleAppDidBecomeActive() {
            print("[Sequence WebView] App returning to foreground")
            // User returned - they might continue onboarding
            // The session is still active, next screen view will be tracked
        }

        // MARK: - WKScriptMessageHandler

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let typeString = body["type"] as? String else {
                print("[Sequence WebView] Invalid message format")
                return
            }

            print("[Sequence WebView] Received message: \(typeString)")

            switch typeString {
            case "buttonTap":
                handleButtonTap(body)

            case "screenChange":
                if let screenId = body["screenId"] as? String {
                    parent.onScreenChange?(screenId)
                    let screenName = body["screenName"] as? String
                    let isFirstView = body["isFirstView"] as? Bool ?? false

                    // Use the new unified tracking method that handles time tracking
                    Sequence.shared.trackScreenEnter(
                        screenId: screenId,
                        screenName: screenName,
                        isFirstView: isFirstView
                    )
                }

            case "onboardingComplete":
                print("[Sequence WebView] Onboarding complete")
                // End session as completed before marking onboarding complete
                Sequence.shared.endSession(completed: true)
                Sequence.shared.markOnboardingCompleted()
                if let data = body["collectedData"] as? [String: Any] {
                    parent.onDataCollected?(data)
                }
                // Flush events immediately
                Task {
                    await Sequence.shared.flush()
                }
                parent.onComplete()

            case "dataCollected":
                if let data = body["data"] as? [String: Any] {
                    parent.onDataCollected?(data)
                }

            case "ready":
                print("[Sequence WebView] Renderer ready")
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }

            case "error":
                let errorMessage = body["message"] as? String ?? "Unknown error"
                print("[Sequence WebView] Error: \(errorMessage)")
                DispatchQueue.main.async {
                    self.parent.error = errorMessage
                    self.parent.isLoading = false
                }

            default:
                print("[Sequence WebView] Unknown message type: \(typeString)")
            }
        }

        private func handleButtonTap(_ body: [String: Any]) {
            guard let action = body["action"] as? [String: Any],
                  let actionType = action["type"] as? String else {
                return
            }

            let screenId = body["screenId"] as? String
            let buttonText = body["buttonText"] as? String ?? ""

            // Track button tap
            if let screenId = screenId {
                Sequence.shared.trackButtonTapped(screenId: screenId, buttonText: buttonText)
            }

            switch actionType {
            case "complete":
                print("[Sequence WebView] Complete action")
                Sequence.shared.endSession(completed: true)
                Sequence.shared.markOnboardingCompleted()
                // Flush events immediately
                Task {
                    await Sequence.shared.flush()
                }
                parent.onComplete()

            case "next", "screen":
                // Navigation handled by web renderer
                break

            default:
                break
            }
        }

        // MARK: - WKNavigationDelegate

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("[Sequence WebView] Started loading")
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[Sequence WebView] Finished loading")

            // Inject accurate viewport dimensions now that the WebView is laid out
            injectAccurateViewport(webView)

            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        /// Injects the accurate WebView bounds into the page
        /// This updates the early estimate with the actual dimensions
        private func injectAccurateViewport(_ webView: WKWebView) {
            let bounds = webView.bounds
            guard bounds.width > 0 && bounds.height > 0 else {
                print("[Sequence WebView] WebView bounds not ready, will retry")
                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak webView] in
                    if let webView = webView {
                        self?.injectAccurateViewport(webView)
                    }
                }
                return
            }

            guard !hasInjectedAccurateViewport else { return }
            hasInjectedAccurateViewport = true

            let script = """
                window.sequenceViewport = {
                    width: \(bounds.width),
                    height: \(bounds.height),
                    isEarlyEstimate: false
                };
                console.log('[Sequence] Accurate viewport injected:', window.sequenceViewport);
                // Dispatch event so FlowRenderer can recalculate scale with accurate dimensions
                window.dispatchEvent(new CustomEvent('sequenceViewportReady', {
                    detail: window.sequenceViewport
                }));
            """
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[Sequence WebView] Failed to inject accurate viewport: \(error)")
                } else {
                    print("[Sequence WebView] Accurate viewport injected: \(bounds.width)x\(bounds.height)")
                }
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[Sequence WebView] Navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.error = error.localizedDescription
                self.parent.isLoading = false
            }
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[Sequence WebView] Provisional navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.error = error.localizedDescription
                self.parent.isLoading = false
            }
        }
    }
}

// MARK: - WebView-based Onboarding View

/// Main onboarding view using WebView for pixel-perfect WYSIWYG rendering
public struct WebViewOnboardingView: View {
    @State private var isLoading = true
    @State private var error: String?
    @State private var collectedData: [String: Any] = [:]

    public var onComplete: () -> Void
    public var onDataCollected: (([String: Any]) -> Void)?

    public init(
        onComplete: @escaping () -> Void,
        onDataCollected: (([String: Any]) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        self.onDataCollected = onDataCollected
    }

    public var body: some View {
        ZStack {
            // WebView renderer
            if let appId = Sequence.shared.appId {
                WebViewRenderer(
                    appId: appId,
                    baseURL: Sequence.shared.baseURL,
                    isLoading: $isLoading,
                    error: $error,
                    onComplete: onComplete,
                    onScreenChange: { screenId in
                        print("[Sequence] Screen changed to: \(screenId)")
                    },
                    onDataCollected: { data in
                        collectedData.merge(data) { _, new in new }
                        onDataCollected?(collectedData)
                    }
                )
                .ignoresSafeArea()
            } else {
                // Not configured error
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Sequence SDK not configured")
                        .font(.headline)
                    Text("Call Sequence.shared.configure() before showing onboarding")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.8)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                .ignoresSafeArea()
            }

            // Error overlay
            if let error = error {
                ZStack {
                    Color.black.opacity(0.9)
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        Text("Failed to load onboarding")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            self.error = nil
                            self.isLoading = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .background(Color.black)
        .ignoresSafeArea(.all)
        .onAppear {
            // Start a new session when onboarding view appears
            Sequence.shared.startSession()
        }
        .onDisappear {
            // If session is still active when view disappears (user dismissed without completing),
            // end the session as dropped off
            if Sequence.shared.currentSessionId != nil {
                Sequence.shared.endSession(completed: false)
                Task {
                    await Sequence.shared.flush()
                }
            }
        }
    }
}

#endif
