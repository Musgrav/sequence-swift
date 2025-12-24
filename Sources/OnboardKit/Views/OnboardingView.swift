// Sequence SwiftUI Views

import SwiftUI

/// Main onboarding view that displays the entire flow
/// Automatically tracks events and handles navigation
public struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    
    /// Called when onboarding is completed or dismissed
    public var onComplete: () -> Void
    
    /// Optional callback for custom native screens
    public var onNativeScreen: ((Screen) -> AnyView)?
    
    public init(
        onComplete: @escaping () -> Void,
        onNativeScreen: ((Screen) -> AnyView)? = nil
    ) {
        self.onComplete = onComplete
        self.onNativeScreen = onNativeScreen
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.fetchConfig() }
                }
            } else if let screen = viewModel.currentScreen {
                screenView(for: screen)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(screen.id)
            } else {
                EmptyStateView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreenIndex)
        .task {
            await viewModel.fetchConfig()
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                onComplete()
            }
        }
    }
    
    @ViewBuilder
    private func screenView(for screen: Screen) -> some View {
        if screen.type == .native, let onNativeScreen = onNativeScreen {
            onNativeScreen(screen)
        } else {
            ScreenView(
                screen: screen,
                totalScreens: viewModel.totalScreens,
                currentIndex: viewModel.currentScreenIndex,
                onButtonTap: { action in
                    viewModel.handleButtonAction(action)
                },
                onSkip: {
                    viewModel.skipCurrentScreen()
                }
            )
        }
    }
}

// MARK: - Screen View

struct ScreenView: View {
    let screen: Screen
    let totalScreens: Int
    let currentIndex: Int
    let onButtonTap: (ButtonAction) -> Void
    let onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                backgroundView
                
                // Content
                VStack(spacing: 0) {
                    // Progress indicator
                    if totalScreens > 1 {
                        ProgressDots(total: totalScreens, current: currentIndex)
                            .padding(.top, 60)
                            .padding(.bottom, 20)
                    } else {
                        Spacer().frame(height: 80)
                    }
                    
                    Spacer()
                    
                    // Main content
                    if screen.content.useBlocks == true, let blocks = screen.content.blocks {
                        BlocksContentView(blocks: blocks, onButtonTap: onButtonTap)
                    } else {
                        SimpleContentView(content: screen.content, onButtonTap: onButtonTap)
                    }
                    
                    Spacer()
                    
                    // Skip button if available
                    if let skipText = screen.content.skipText {
                        Button(action: onSkip) {
                            Text(skipText)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.bottom, 40)
                    } else {
                        Spacer().frame(height: 40)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            Sequence.shared.trackScreenViewed(screenId: screen.id, screenName: screen.name)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if let gradient = screen.content.backgroundGradient {
            let colors = gradient.colors.compactMap { Color(hex: $0) }
            if gradient.type == .linear {
                LinearGradient(
                    colors: colors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        } else {
            Color(hex: screen.content.backgroundColor ?? "#0f172a")
        }
    }
}

// MARK: - Simple Content View (Legacy)

struct SimpleContentView: View {
    let content: ScreenContent
    let onButtonTap: (ButtonAction) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            if let icon = content.icon {
                Text(icon)
                    .font(.system(size: 64))
                    .padding(.bottom, 8)
            }
            
            // Title
            if let title = content.title {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: content.titleColor ?? "#ffffff"))
                    .multilineTextAlignment(.center)
            }
            
            // Subtitle / Body
            if let subtitle = content.subtitle ?? content.body {
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: content.subtitleColor ?? "#94a3b8"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            Spacer().frame(height: 24)
            
            // Button
            Button(action: {
                let action = content.buttonAction ?? .next
                onButtonTap(action)
            }) {
                Text(content.buttonText ?? "Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: content.buttonTextColor ?? "#ffffff"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: content.buttonColor ?? "#10b981"))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Blocks Content View

struct BlocksContentView: View {
    let blocks: [ContentBlock]
    let onButtonTap: (ButtonAction) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(blocks.sorted(by: { $0.order < $1.order })) { block in
                BlockView(block: block, onButtonTap: onButtonTap)
            }
        }
    }
}

struct BlockView: View {
    let block: ContentBlock
    let onButtonTap: (ButtonAction) -> Void
    
    var body: some View {
        switch block.type {
        case .text:
            TextBlockView(content: block.content)
        case .icon:
            IconBlockView(content: block.content)
        case .button:
            ButtonBlockView(content: block.content, onTap: onButtonTap)
        case .spacer:
            SpacerBlockView(content: block.content)
        case .image:
            ImageBlockView(content: block.content)
        case .divider:
            DividerBlockView(content: block.content)
        case .input:
            InputBlockView(content: block.content)
        case .checklist:
            ChecklistBlockView(content: block.content)
        case .video:
            VideoBlockView(content: block.content)
        case .progress:
            ProgressBlockView(content: block.content)
        case .lottie, .custom, .unknown:
            // Custom/unknown blocks require native implementation
            EmptyView()
        }
    }
}

struct TextBlockView: View {
    let content: BlockContent
    
    var body: some View {
        Text(content.text ?? "")
            .font(fontForVariant(content.variant))
            .fontWeight(weightForString(content.fontWeight))
            .foregroundColor(Color(hex: content.color ?? "#ffffff"))
            .multilineTextAlignment(alignmentForString(content.align))
            .frame(maxWidth: .infinity, alignment: frameAlignmentForString(content.align))
    }
    
    private func fontForVariant(_ variant: String?) -> Font {
        switch variant {
        case "h1": return .system(size: 34, weight: .bold)
        case "h2": return .system(size: 28, weight: .bold)
        case "h3": return .system(size: 22, weight: .semibold)
        case "caption": return .system(size: 12)
        case "label": return .system(size: 14, weight: .medium)
        default: return .system(size: 16)
        }
    }
    
    private func weightForString(_ weight: String?) -> Font.Weight {
        switch weight {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        default: return .regular
        }
    }
    
    private func alignmentForString(_ align: String?) -> TextAlignment {
        switch align {
        case "left": return .leading
        case "right": return .trailing
        default: return .center
        }
    }
    
    private func frameAlignmentForString(_ align: String?) -> Alignment {
        switch align {
        case "left": return .leading
        case "right": return .trailing
        default: return .center
        }
    }
}

struct IconBlockView: View {
    let content: BlockContent
    
    var body: some View {
        Text(content.icon ?? "")
            .font(.system(size: sizeForString(content.size)))
    }
    
    private func sizeForString(_ size: String?) -> CGFloat {
        switch size {
        case "sm": return 24
        case "md": return 32
        case "lg": return 48
        case "xl": return 64
        case "2xl": return 80
        default: return 48
        }
    }
}

struct ButtonBlockView: View {
    let content: BlockContent
    let onTap: (ButtonAction) -> Void
    
    var body: some View {
        Button(action: {
            let action = content.action ?? .next
            onTap(action)
        }) {
            Text(content.text ?? "Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(hex: content.backgroundColor ?? "#10b981"))
                .cornerRadius(CGFloat(content.borderRadius ?? 12))
        }
    }
}

struct SpacerBlockView: View {
    let content: BlockContent
    
    var body: some View {
        let spacerHeight: CGFloat = {
            switch content.height {
            case .number(let value):
                return CGFloat(value)
            case .string(let str):
                return CGFloat(Int(str) ?? 16)
            case .none:
                return 16
            }
        }()
        Spacer().frame(height: spacerHeight)
    }
}

struct ImageBlockView: View {
    let content: BlockContent
    
    var body: some View {
        if let src = content.src, let url = URL(string: src) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(CGFloat(content.borderRadius ?? 0))
        }
    }
}

struct DividerBlockView: View {
    let content: BlockContent
    
    var body: some View {
        Rectangle()
            .fill(Color(hex: content.color ?? "#333333"))
            .frame(height: CGFloat(content.thickness ?? 1))
            .frame(maxWidth: .infinity)
    }
}

struct InputBlockView: View {
    let content: BlockContent
    @State private var text: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            if let label = content.label {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: content.color ?? "#ffffff"))
            }
            
            // Text field
            TextField(content.placeholder ?? "", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: content.backgroundColor ?? "#1e293b"))
                .cornerRadius(CGFloat(content.borderRadius ?? 12))
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(content.borderRadius ?? 12))
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChecklistBlockView: View {
    let content: BlockContent
    @State private var selectedItems: Set<String> = []
    
    var body: some View {
        VStack(spacing: 12) {
            if let items = content.items {
                ForEach(items) { item in
                    ChecklistItemView(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        allowMultiple: content.allowMultiple ?? true,
                        onToggle: {
                            toggleItem(item)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func toggleItem(_ item: ChecklistItem) {
        if content.allowMultiple == true || content.allowMultiple == nil {
            // Multiple selection allowed
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
        } else {
            // Single selection only
            selectedItems = [item.id]
        }
    }
}

struct ChecklistItemView: View {
    let item: ChecklistItem
    let isSelected: Bool
    let allowMultiple: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox/Radio indicator
                ZStack {
                    if allowMultiple {
                        // Checkbox style
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color(hex: "#10b981") : Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#10b981"))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        // Radio style
                        Circle()
                            .stroke(isSelected ? Color(hex: "#10b981") : Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color(hex: "#10b981"))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
                
                // Label
                Text(item.label)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#10b981").opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "#10b981") : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VideoBlockView: View {
    let content: BlockContent
    
    var body: some View {
        if let src = content.src, URL(string: src) != nil {
            // Video player placeholder with poster image
            ZStack {
                if let poster = content.poster, let posterUrl = URL(string: poster) {
                    AsyncImage(url: posterUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(hex: "#1e293b"))
                    }
                } else {
                    Rectangle()
                        .fill(Color(hex: "#1e293b"))
                }
                
                // Play button overlay
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#0f172a"))
                    .offset(x: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .cornerRadius(CGFloat(content.borderRadius ?? 12))
            .clipped()
        }
    }
}

struct ProgressBlockView: View {
    let content: BlockContent
    
    var body: some View {
        // Simple progress bar placeholder
        // The actual progress would be controlled by the parent view
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: content.color ?? "#10b981"))
                    .frame(width: geometry.size.width * 0.5, height: 8)
            }
        }
        .frame(height: 8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress Dots

struct ProgressDots: View {
    let total: Int
    let current: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0f172a")
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Error View

struct ErrorView: View {
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
        .ignoresSafeArea()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0f172a")
            
            VStack(spacing: 16) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                
                Text("No screens configured")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Add screens in the Sequence dashboard")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

