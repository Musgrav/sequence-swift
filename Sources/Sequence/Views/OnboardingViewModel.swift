// Sequence View Model

import SwiftUI
import Combine
import OSLog
import UIKit

let viewModelLogger = Logger(subsystem: "com.sequence.sdk", category: "OnboardingViewModel")

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var config: OnboardingConfig?
    @Published var currentScreenIndex: Int = 0
    @Published var isLoading = true
    @Published var error: SequenceError?
    @Published var isCompleted = false
    
    private let sequence = Sequence.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentScreenIdForDropOff: String? // Track current screen for drop-off detection
    
    var currentScreen: Screen? {
        guard let config = config, currentScreenIndex < config.screens.count else {
            return nil
        }
        return sortedScreens[currentScreenIndex]
    }
    
    var sortedScreens: [Screen] {
        config?.screens.sorted(by: { $0.order < $1.order }) ?? []
    }
    
    var totalScreens: Int {
        config?.screens.count ?? 0
    }
    
    init() {
        print("🏗️ [OnboardingViewModel] init called")
        // Observe changes from the shared Sequence instance
        sequence.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                print("🔄 [OnboardingViewModel] config updated: \(config?.screens.count ?? 0) screens")
                self?.config = config
            }
            .store(in: &cancellables)
        print("🏗️ [OnboardingViewModel] init completed")
    }
    
    func fetchConfig() async {
        isLoading = true
        error = nil
        
        do {
            let config = try await sequence.fetchConfig()
            self.config = config
            
            // Track onboarding started
            sequence.track(eventType: .onboardingStarted)
            
            // Set up app lifecycle observers for drop-off tracking
            setupAppLifecycleObservers()
            
        } catch let err as SequenceError {
            self.error = err
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Set up observers to track drop-offs when app goes to background
    private func setupAppLifecycleObservers() {
        // Observe scene phase changes (iOS 13+)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.trackDropOffIfNeeded(reason: "app_will_resign_active")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.trackDropOffIfNeeded(reason: "app_did_enter_background")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.trackDropOffIfNeeded(reason: "app_will_terminate")
            }
            .store(in: &cancellables)
    }
    
    /// Track drop-off if user is currently viewing a screen
    private func trackDropOffIfNeeded(reason: String) {
        guard let screenId = currentScreenIdForDropOff,
              !isCompleted else {
            return
        }
        
        let screenName = currentScreen?.name
        sequence.trackScreenDroppedOff(screenId: screenId, screenName: screenName, reason: reason)
        
        // Force flush immediately for drop-off events (critical)
        sequence.forceFlush()
        
        // Clear current screen to avoid duplicate tracking
        currentScreenIdForDropOff = nil
    }
    
    var onCustomAction: ((String) -> Void)?
    
    func handleButtonAction(_ action: ButtonAction) {
        guard let currentScreen = currentScreen else {
            viewModelLogger.error("❌ [ViewModel] handleButtonAction called but no currentScreen")
            print("❌ [ViewModel] handleButtonAction called but no currentScreen")
            return
        }
        
        viewModelLogger.info("🔧 [ViewModel] handleButtonAction: \(String(describing: action)), currentScreen: \(currentScreen.name) (index: \(self.currentScreenIndex))")
        print("🔧 [ViewModel] handleButtonAction: \(action), currentScreen: \(currentScreen.name) (index: \(currentScreenIndex))")
        
        // Track button tap
        sequence.trackButtonTapped(
            screenId: currentScreen.id,
            buttonText: currentScreen.content.buttonText ?? "Continue"
        )
        
        switch action {
        case .next:
            print("🔧 [ViewModel] Action: next")
            goToNextScreen()
        case .previous:
            print("🔧 [ViewModel] Action: previous")
            goToPreviousScreen()
        case .screen(let screenId):
            print("🔧 [ViewModel] Action: screen(\(screenId))")
            goToScreen(id: screenId)
        case .complete:
            print("🔧 [ViewModel] Action: complete")
            completeOnboarding()
        case .custom(let identifier):
            print("🔧 [ViewModel] Action: custom(\(identifier))")
            onCustomAction?(identifier)
        }
    }
    
    func goToNextScreen() {
        guard let currentScreen = currentScreen else { return }
        
        // Track screen completed
        sequence.trackScreenCompleted(screenId: currentScreen.id, screenName: currentScreen.name)
        
        // Clear drop-off tracking since we're advancing
        currentScreenIdForDropOff = nil
        
        if currentScreenIndex < totalScreens - 1 {
            withAnimation {
                currentScreenIndex += 1
            }
            // Set new screen for drop-off tracking
            if let newScreen = self.currentScreen {
                currentScreenIdForDropOff = newScreen.id
            }
        } else {
            completeOnboarding()
        }
    }
    
    func goToPreviousScreen() {
        guard let currentScreen = currentScreen else { return }
        
        // Track screen completed
        sequence.trackScreenCompleted(screenId: currentScreen.id, screenName: currentScreen.name)
        
        // Clear drop-off tracking since we're navigating
        currentScreenIdForDropOff = nil
        
        if currentScreenIndex > 0 {
            withAnimation {
                currentScreenIndex -= 1
            }
            // Set new screen for drop-off tracking
            if let newScreen = self.currentScreen {
                currentScreenIdForDropOff = newScreen.id
            }
        }
    }
    
    func goToScreen(id: String) {
        guard let currentScreen = currentScreen else { return }
        
        // Track screen completed
        sequence.trackScreenCompleted(screenId: currentScreen.id, screenName: currentScreen.name)
        
        // Clear drop-off tracking since we're navigating
        currentScreenIdForDropOff = nil
        
        if let index = sortedScreens.firstIndex(where: { $0.id == id }) {
            withAnimation {
                currentScreenIndex = index
            }
            // Set new screen for drop-off tracking
            if let newScreen = self.currentScreen {
                currentScreenIdForDropOff = newScreen.id
            }
        }
    }
    
    func skipCurrentScreen() {
        guard let currentScreen = currentScreen else { return }
        
        // Track screen skipped
        sequence.trackScreenSkipped(screenId: currentScreen.id, screenName: currentScreen.name)
        
        // Handle skip action if defined, otherwise go to next
        if let skipAction = currentScreen.content.skipAction {
            handleButtonAction(skipAction)
        } else {
            goToNextScreen()
        }
    }
    
    func completeOnboarding() {
        // Clear drop-off tracking since onboarding is complete
        currentScreenIdForDropOff = nil
        
        sequence.markOnboardingCompleted()
        
        // Flush events immediately
        Task {
            await sequence.flush()
        }
        
        isCompleted = true
    }
    
    /// Set the current screen ID for drop-off tracking
    func setCurrentScreenForDropOff(_ screenId: String) {
        currentScreenIdForDropOff = screenId
    }
}

