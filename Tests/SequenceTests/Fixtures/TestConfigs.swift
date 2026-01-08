import Foundation
@testable import Sequence

/// Test configurations for performance testing
enum TestConfigs {

    // MARK: - Simple Config (1 screen, minimal content)

    /// Simple configuration with a single welcome screen
    /// Use case: Fast path testing
    static let simple: OnboardingConfig = {
        let content = ScreenContent(
            title: "Welcome",
            subtitle: "Get started",
            backgroundColor: "#0f172a",
            titleColor: "#ffffff",
            subtitleColor: "#d1d5db",
            buttonText: "Continue",
            buttonColor: "#10b981",
            buttonTextColor: "#ffffff",
            buttonAction: .next
        )

        let screen = Screen(
            id: "welcome",
            name: "Welcome",
            type: .welcome,
            order: 0,
            content: content
        )

        return OnboardingConfig(
            version: 1,
            screens: [screen],
            experiment: nil,
            progressIndicator: nil
        )
    }()

    // MARK: - Standard Config (3 screens, realistic content)

    /// Standard configuration with 3 screens and mixed content
    /// Use case: Typical onboarding flow
    static let standard: OnboardingConfig = {
        let screens = [
            Screen(
                id: "screen_1",
                name: "Welcome",
                type: .welcome,
                order: 0,
                content: ScreenContent(
                    title: "Welcome to Sequence",
                    subtitle: "Build powerful onboarding flows",
                    backgroundColor: "#0f172a",
                    titleColor: "#ffffff",
                    subtitleColor: "#d1d5db",
                    buttonText: "Next",
                    buttonColor: "#10b981",
                    buttonAction: .next
                )
            ),
            Screen(
                id: "screen_2",
                name: "Features",
                type: .feature,
                order: 1,
                content: ScreenContent(
                    title: "Key Features",
                    subtitle: "Everything you need",
                    backgroundColor: "#ffffff",
                    titleColor: "#1f2937",
                    subtitleColor: "#6b7280",
                    buttonText: "Next",
                    buttonColor: "#10b981",
                    buttonAction: .next
                )
            ),
            Screen(
                id: "screen_3",
                name: "Call to Action",
                type: .welcome,
                order: 2,
                content: ScreenContent(
                    title: "Ready to Get Started?",
                    subtitle: "Join thousands of happy users",
                    backgroundColor: "#10b981",
                    titleColor: "#ffffff",
                    subtitleColor: "#d1f4e6",
                    buttonText: "Complete Setup",
                    buttonColor: "#059669",
                    buttonAction: .complete
                )
            )
        ]

        return OnboardingConfig(
            version: 1,
            screens: screens,
            experiment: nil,
            progressIndicator: FlowProgressIndicator(
                enabled: true,
                variant: .dots,
                position: .bottom,
                fillColor: "#10b981",
                trackColor: "rgba(255,255,255,0.2)",
                animated: true,
                startScreen: 0,
                endScreen: 2
            )
        )
    }()

    // MARK: - Complex Config (5 screens, rich content)

    /// Complex configuration with 5 screens and rich content
    /// Use case: Feature-rich onboarding with experiment tracking
    static let complex: OnboardingConfig = {
        let screens = [
            Screen(
                id: "intro",
                name: "Introduction",
                type: .welcome,
                order: 0,
                content: ScreenContent(
                    title: "Introducing Sequence",
                    subtitle: "Powerful onboarding for modern apps",
                    image: nil,
                    backgroundColor: "#0f172a",
                    titleColor: "#ffffff",
                    subtitleColor: "#d1d5db",
                    buttonText: "Explore",
                    buttonColor: "#10b981",
                    buttonTextColor: "#ffffff",
                    buttonAction: .next,
                    icon: "⭐"
                )
            ),
            Screen(
                id: "features_1",
                name: "Analytics",
                type: .feature,
                order: 1,
                content: ScreenContent(
                    title: "Real-time Analytics",
                    subtitle: "Track user engagement instantly",
                    backgroundColor: "#ffffff",
                    titleColor: "#1f2937",
                    subtitleColor: "#6b7280",
                    buttonText: "Continue",
                    buttonColor: "#10b981",
                    buttonAction: .next,
                    icon: "📊"
                )
            ),
            Screen(
                id: "features_2",
                name: "Testing",
                type: .feature,
                order: 2,
                content: ScreenContent(
                    title: "A/B Testing",
                    subtitle: "Run experiments automatically",
                    backgroundColor: "#f9fafb",
                    titleColor: "#1f2937",
                    subtitleColor: "#6b7280",
                    buttonText: "Next",
                    buttonColor: "#10b981",
                    buttonAction: .next,
                    icon: "🧪"
                )
            ),
            Screen(
                id: "personalization",
                name: "Personalization",
                type: .feature,
                order: 3,
                content: ScreenContent(
                    title: "Personalize Your Experience",
                    subtitle: "Customize to match your brand",
                    backgroundColor: "#ffffff",
                    titleColor: "#1f2937",
                    subtitleColor: "#6b7280",
                    buttonText: "Next",
                    buttonColor: "#10b981",
                    buttonAction: .next,
                    icon: "🎨"
                )
            ),
            Screen(
                id: "final_cta",
                name: "Final Call to Action",
                type: .welcome,
                order: 4,
                content: ScreenContent(
                    title: "You're All Set!",
                    subtitle: "Start creating amazing onboardings",
                    backgroundColor: "#10b981",
                    titleColor: "#ffffff",
                    subtitleColor: "#d1f4e6",
                    buttonText: "Get Started",
                    buttonColor: "#059669",
                    buttonTextColor: "#ffffff",
                    buttonAction: .complete,
                    icon: "✨"
                )
            )
        ]

        return OnboardingConfig(
            version: 1,
            screens: screens,
            experiment: ExperimentInfo(
                id: "test_flow_v2",
                variantId: "variant_a",
                variantName: "Control"
            ),
            progressIndicator: FlowProgressIndicator(
                enabled: true,
                variant: .bar,
                position: .top,
                fillColor: "#10b981",
                trackColor: "rgba(0,0,0,0.1)",
                animated: true,
                startScreen: 0,
                endScreen: 4
            )
        )
    }()
}
