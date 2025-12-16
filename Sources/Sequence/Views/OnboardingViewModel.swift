// Sequence View Model

import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var config: OnboardingConfig?
    @Published var currentScreenIndex: Int = 0
    @Published var isLoading = true
    @Published var error: SequenceError?
    @Published var isCompleted = false
    
    private let sequence = Sequence.shared
    private var cancellables = Set<AnyCancellable>()
    
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
        // Observe changes from the shared Sequence instance
        sequence.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.config = config
            }
            .store(in: &cancellables)
    }
    
    func fetchConfig() async {
        isLoading = true
        error = nil
        
        do {
            let config = try await sequence.fetchConfig()
            self.config = config
            
            // Track onboarding started
            sequence.track(eventType: .onboardingStarted)
            
        } catch let err as SequenceError {
            self.error = err
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func handleButtonAction(_ action: ButtonAction) {
        guard let currentScreen = currentScreen else { return }
        
        // Track button tap
        sequence.trackButtonTapped(
            screenId: currentScreen.id,
            buttonText: currentScreen.content.buttonText ?? "Continue"
        )
        
        switch action {
        case .next:
            goToNextScreen()
        case .screen(let screenId):
            goToScreen(id: screenId)
        case .complete:
            completeOnboarding()
        }
    }
    
    func goToNextScreen() {
        guard let currentScreen = currentScreen else { return }
        
        // Track screen completed
        sequence.trackScreenCompleted(screenId: currentScreen.id, screenName: currentScreen.name)
        
        if currentScreenIndex < totalScreens - 1 {
            withAnimation {
                currentScreenIndex += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    func goToScreen(id: String) {
        guard let currentScreen = currentScreen else { return }
        
        // Track screen completed
        sequence.trackScreenCompleted(screenId: currentScreen.id, screenName: currentScreen.name)
        
        if let index = sortedScreens.firstIndex(where: { $0.id == id }) {
            withAnimation {
                currentScreenIndex = index
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
        sequence.markOnboardingCompleted()
        
        // Flush events immediately
        Task {
            await sequence.flush()
        }
        
        isCompleted = true
    }
}

