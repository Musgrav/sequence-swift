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

        // Disable caching for development
        #if DEBUG
        webView.configuration.websiteDataStore = .nonPersistent()
        #endif

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
        // Updates handled by coordinator
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

        init(_ parent: WebViewRenderer) {
            self.parent = parent
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
                    // Track the event
                    Sequence.shared.trackScreenViewed(
                        screenId: screenId,
                        screenName: body["screenName"] as? String
                    )
                }

            case "onboardingComplete":
                print("[Sequence WebView] Onboarding complete")
                Sequence.shared.markOnboardingCompleted()
                if let data = body["collectedData"] as? [String: Any] {
                    parent.onDataCollected?(data)
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
                Sequence.shared.markOnboardingCompleted()
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
            DispatchQueue.main.async {
                self.parent.isLoading = false
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
    }
}

#endif
