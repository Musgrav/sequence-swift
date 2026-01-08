// Sequence SwiftUI Views

import SwiftUI
import OSLog

let logger = Logger(subsystem: "com.sequence.sdk", category: "OnboardingView")

/// Main onboarding view that displays the entire flow
/// Automatically tracks events and handles navigation
public struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    
    /// Called when onboarding is completed or dismissed
    public var onComplete: () -> Void
    
    /// Optional callback for custom native screens
    public var onNativeScreen: ((Screen) -> AnyView)?
    
    /// Optional callback for custom actions (auth, permissions, etc.)
    public var onCustomAction: ((String) -> Void)?
    
    public init(
        onComplete: @escaping () -> Void,
        onNativeScreen: ((Screen) -> AnyView)? = nil,
        onCustomAction: ((String) -> Void)? = nil
    ) {
        print("🏗️ [OnboardingView] init called")
        self.onComplete = onComplete
        self.onNativeScreen = onNativeScreen
        self.onCustomAction = onCustomAction
    }
    
    /// Convenience init for backward compatibility (2-parameter version)
    public init(
        onComplete: @escaping () -> Void,
        onNativeScreen: ((Screen) -> AnyView)?
    ) {
        print("🏗️ [OnboardingView] init (2-param) called")
        self.onComplete = onComplete
        self.onNativeScreen = onNativeScreen
        self.onCustomAction = nil
    }
    
    public var body: some View {
        let _ = print("📱 [OnboardingView] body called - isLoading: \(viewModel.isLoading), hasConfig: \(viewModel.config != nil), screenCount: \(viewModel.totalScreens)")
        
        ZStack {
            // Base background to prevent white flash
            Color(hex: "#0f172a")
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                LoadingView()
                    .onAppear { print("🔵 [OnboardingView] State: LOADING") }
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.fetchConfig() }
                }
                .onAppear { print("🔴 [OnboardingView] State: ERROR - \(error)") }
            } else if let screen = viewModel.currentScreen {
                screenView(for: screen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.all)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(screen.id)
                    .onAppear { print("🟢 [OnboardingView] State: SHOWING SCREEN '\(screen.name)'") }
            } else {
                EmptyStateView()
                    .onAppear { print("⚪ [OnboardingView] State: EMPTY (no screens)") }
            }
            
            // Progress indicator overlay - OUTSIDE of screen transitions so it doesn't flash
            // This is rendered at the OnboardingView level to persist across screen changes
            if !viewModel.isLoading,
               viewModel.error == nil,
               viewModel.currentScreen != nil,
               let indicator = viewModel.config?.progressIndicator,
               indicator.enabled,
               viewModel.totalScreens > 1 {
                progressOverlay(indicator: indicator)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentScreenIndex)
        .task {
            print("🚀 [OnboardingView] Starting fetchConfig...")
            await viewModel.fetchConfig()
            print("🚀 [OnboardingView] fetchConfig completed. Screens: \(viewModel.totalScreens)")
        }
        .onAppear {
            print("👁️ [OnboardingView] View appeared")
            viewModel.onCustomAction = onCustomAction
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                onComplete()
            }
        }
    }
    
    // Progress overlay - rendered at OnboardingView level to prevent flashing
    @ViewBuilder
    private func progressOverlay(indicator: FlowProgressIndicator) -> some View {
        if indicator.position == .top {
            VStack {
                FlowProgressView(
                    indicator: indicator,
                    currentIndex: viewModel.currentScreenIndex,
                    totalScreens: viewModel.totalScreens
                )
                .padding(.top, 60)
                Spacer()
            }
        } else {
            VStack {
                Spacer()
                FlowProgressView(
                    indicator: indicator,
                    currentIndex: viewModel.currentScreenIndex,
                    totalScreens: viewModel.totalScreens
                )
                .padding(.bottom, 40)
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
                progressIndicator: viewModel.config?.progressIndicator,
                onButtonTap: { action in
                    viewModel.handleButtonAction(action)
                },
                onScreenAppear: {
                    viewModel.setCurrentScreenForDropOff(screen.id)
                },
                onSkip: {
                    viewModel.skipCurrentScreen()
                }
            )
        }
    }
}

// MARK: - Progress Indicator Top Padding
// Provides consistent padding for content when progress indicator is at top
extension FlowProgressIndicator {
    /// Returns the top padding needed to accommodate the progress indicator
    var topContentPadding: CGFloat {
        guard enabled else { return 0 }
        guard position == .top else { return 0 }
        // Progress indicator is at top with 60pt padding + indicator height (~20pt) + spacing
        return 40 // Additional padding below the progress bar
    }
}

// MARK: - Screen View

struct ScreenView: View {
    let screen: Screen
    let totalScreens: Int
    let currentIndex: Int
    let progressIndicator: FlowProgressIndicator?
    let onButtonTap: (ButtonAction) -> Void
    let onScreenAppear: () -> Void
    let onSkip: () -> Void
    
    // Calculate extra top padding when progress indicator is at top
    private var extraTopPadding: CGFloat {
        guard let indicator = progressIndicator,
              indicator.enabled,
              indicator.position == .top,
              totalScreens > 1 else { return 0 }
        return 40 // Extra padding below the progress bar
    }
    
    // Convert old blocks to declarative layout
    private var declarativeLayout: ScreenLayout {
        let layout = LayoutConverter.convert(
            from: screen.content, 
            screenId: screen.id,
            extraTopPadding: extraTopPadding
        )
        print("🎨 [ScreenView] Converted layout for '\(screen.name)':")
        print("🎨 [ScreenView]   - Root type: \(layout.root.type)")
        print("🎨 [ScreenView]   - Root children: \(layout.root.children?.count ?? 0)")
        print("🎨 [ScreenView]   - Background: \(layout.backgroundColor ?? "nil")")
        print("🎨 [ScreenView]   - Extra top padding: \(extraTopPadding)")
        return layout
    }
    
    // Adapter to convert LayoutButtonAction to ButtonAction
    private func handleLayoutAction(_ action: LayoutButtonAction) {
        print("🎨 [ScreenView] Button tapped: \(action)")
        switch action {
        case .next:
            onButtonTap(.next)
        case .previous:
            onButtonTap(.previous)
        case .screen(let screenId):
            onButtonTap(.screen(screenId: screenId))
        case .complete:
            onButtonTap(.complete)
        case .custom(let identifier):
            onButtonTap(.custom(identifier: identifier))
        }
    }
    
    var body: some View {
        ZStack {
            // Background layer - fills entire screen including safe areas
            backgroundView
            
            // Content layer
            ScreenLayoutView(
                layout: declarativeLayout,
                onButtonTap: handleLayoutAction
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .ignoresSafeArea(.all)
        .onAppear {
            print("🎨 [ScreenView] Rendering '\(screen.name)' using DECLARATIVE layout")
            // Track all views for debugging/analytics
            Sequence.shared.trackScreenViewed(screenId: screen.id, screenName: screen.name)
            // Track first view only (deduplicated)
            Sequence.shared.trackScreenFirstViewed(screenId: screen.id, screenName: screen.name)
            // Set current screen for drop-off tracking
            onScreenAppear()
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
                    endRadius: 500
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
    
    // ============================================
    // Design Canvas Dimensions
    // ============================================
    // These MUST match web/src/lib/device-constants.ts
    // Based on iPhone 15/16 Pro dimensions (393 × 852 points)
    // ============================================
    private let editorCanvasWidth: CGFloat = 393
    private let editorCanvasHeight: CGFloat = 852
    
    // Filter to only visible blocks (visible is true by default if not set)
    private var visibleBlocks: [ContentBlock] {
        blocks.filter { $0.visible != false }
    }
    
    var body: some View {
        GeometryReader { geometry in
            absolutePositionedContent(blocks: visibleBlocks, in: geometry)
                .onAppear {
                    logger.info("🎨 [Sequence SDK] === CANVAS RENDER ===")
                    logger.info("🎨 [Sequence SDK] Device size: \(geometry.size.width) x \(geometry.size.height)")
                    logger.info("🎨 [Sequence SDK] Visible blocks: \(visibleBlocks.count)")
                    print("🎨 [Sequence SDK] === CANVAS RENDER ===")
                    print("🎨 [Sequence SDK] Device size: \(geometry.size.width) x \(geometry.size.height)")
                    print("🎨 [Sequence SDK] Total blocks: \(blocks.count), Visible blocks: \(visibleBlocks.count)")
                    
                    // Log each block
                    for (index, block) in visibleBlocks.enumerated() {
                        if let pos = block.position {
                            print("🎨 [Sequence SDK] Block[\(index)] '\(block.type)' HAS position: (\(pos.x), \(pos.y))")
                        } else {
                            print("⚠️ [Sequence SDK] Block[\(index)] '\(block.type)' NO POSITION (will use default)")
                        }
                    }
                    
                    print("🎨 [Sequence SDK] ✅ Using ABSOLUTE POSITIONED mode (WYSIWYG)")
                }
        }
    }
    
    // WYSIWYG canvas-based rendering for blocks with stored positions
    @ViewBuilder
    private func absolutePositionedContent(blocks: [ContentBlock], in geometry: GeometryProxy) -> some View {
        // Calculate scale factors
        // For horizontal: scale based on width to maintain proper positioning
        // For vertical: we'll use the same scale to keep proportions, but fill the screen
        let scaleX = geometry.size.width / editorCanvasWidth
        let scaleY = geometry.size.height / editorCanvasHeight
        
        // Use width-based scale for proportional positioning of blocks
        // This ensures blocks scale proportionally while the background fills the screen
        let uniformScale = scaleX
        
        // Different max widths for different block types (all scaled):
        // - Text blocks: 280px (matches web's max-w-[280px])
        // - Checklist/Input/Full-width blocks: canvas width - 48px padding (24px each side)
        let textMaxWidth: CGFloat = 280 * uniformScale
        let fullWidthMaxWidth: CGFloat = (editorCanvasWidth - 48) * uniformScale // 345px scaled
        
        let _ = print("🎨 [Sequence SDK] === RENDERING INFO ===")
        let _ = print("🎨 [Sequence SDK] Device geometry: \(geometry.size.width) x \(geometry.size.height)")
        let _ = print("🎨 [Sequence SDK] Editor canvas: \(editorCanvasWidth) x \(editorCanvasHeight)")
        let _ = print("🎨 [Sequence SDK] Scale X: \(scaleX), Scale Y: \(scaleY), Using: \(uniformScale)")
        
        ZStack(alignment: .topLeading) {
            // Compute default positions for blocks that don't have them
            let sortedBlocks = blocks.sorted(by: { $0.order < $1.order })
            let centerX: CGFloat = 24 // 24px padding from left edge in design space
            
            ForEach(Array(sortedBlocks.enumerated()), id: \.element.id) { index, block in
                // Use stored position or compute default using a closure to avoid ViewBuilder interpretation
                let pos: BlockPosition = {
                    if let storedPos = block.position {
                        return storedPos
                    } else {
                        // Compute default position based on block order
                        var defaultX = centerX
                        let defaultY: CGFloat = 150 + CGFloat(index) * 70 // Simple vertical stacking
                        
                        // Center icons
                        if block.type == .icon {
                            defaultX = editorCanvasWidth / 2 - 40
                        }
                        
                        return BlockPosition(x: defaultX, y: defaultY)
                    }
                }()
                
                // Scale the position to device coordinates
                // Use width scale for X, and proportional Y scale
                let scaledX = pos.x * uniformScale
                let scaledY = pos.y * scaleY  // Use Y scale for vertical positioning to fill screen
                
                // Determine maxWidth based on block type
                // Full-width blocks: checklist, input, slider, progress, divider
                // Text-width blocks: text, icon, image, button
                let blockMaxWidth: CGFloat = {
                    switch block.type {
                    case .checklist, .input, .progress, .divider:
                        return fullWidthMaxWidth
                    default:
                        return textMaxWidth
                    }
                }()
                
                let _ = print("🎨 [Sequence SDK] Block[\(index)] '\(block.type)': editor pos=(\(pos.x), \(pos.y)) → scaled pos=(\(scaledX), \(scaledY)), maxWidth=\(blockMaxWidth)")
                
                // CRITICAL: Position represents TOP-LEFT corner of the block
                // (matching web editor's CSS position: absolute; left: X; top: Y)
                BlockView(block: block, onButtonTap: onButtonTap, maxWidth: blockMaxWidth, scaleFactor: uniformScale)
                    .offset(x: scaledX, y: scaledY)
            }
        }
        // Fill the entire screen - background is handled by ScreenView
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        .onAppear {
            print("🎨 [Sequence SDK] Absolute mode rendered - scale: \(uniformScale), screen: \(geometry.size.width)x\(geometry.size.height)")
            print("🎨 [Sequence SDK] Rendering \(blocks.count) blocks with font scaling")
        }
    }
    
    // Centered stacked layout for blocks without positions
    @ViewBuilder
    private func centeredStackedContent(in geometry: GeometryProxy) -> some View {
        let _ = print("🎨 [Sequence SDK] Stacked mode - using VStack centered layout")
        
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Add top padding to account for status bar/notch
                Spacer().frame(height: 60)
                
                ForEach(visibleBlocks.sorted(by: { $0.order < $1.order })) { block in
                    let _ = print("🎨 [Sequence SDK]   Block '\(block.type)' id=\(block.id)")
                    
                    BlockView(block: block, onButtonTap: onButtonTap, maxWidth: geometry.size.width - 48)
                        .frame(maxWidth: .infinity)
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct BlockView: View {
    let block: ContentBlock
    let onButtonTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing (1.0 = design size, <1.0 = smaller device, >1.0 = larger device)
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        // Skip rendering if block is not visible
        if block.visible == false {
            EmptyView()
        } else {
            contentView
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch block.type {
        case .text:
            TextBlockView(content: block.content, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .icon:
            IconBlockView(content: block.content, scaleFactor: scaleFactor)
        case .button:
            ButtonBlockView(content: block.content, onTap: onButtonTap, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .spacer:
            SpacerBlockView(content: block.content, scaleFactor: scaleFactor)
        case .image:
            ImageBlockView(content: block.content, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .divider:
            DividerBlockView(content: block.content, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .input:
            InputBlockView(content: block.content, styling: block.styling, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .checklist:
            ChecklistBlockView(content: block.content, onButtonTap: onButtonTap, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .video:
            VideoBlockView(content: block.content, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .progress:
            ProgressBlockView(content: block.content, maxWidth: maxWidth, scaleFactor: scaleFactor)
        case .lottie, .custom, .unknown:
            // Custom/unknown blocks require native implementation
            EmptyView()
        }
    }
}

struct TextBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    /// Scale factor for proportional font sizing
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        // Match web editor's behavior:
        // Web uses: width: fit-content; max-width: 280px; text-align: [alignment]
        // The position represents the TOP-LEFT of the text container
        //
        // In SwiftUI:
        // - Text naturally sizes to content
        // - .frame(maxWidth:) sets the max width for wrapping
        // - .multilineTextAlignment() sets text alignment within
        // - Do NOT use alignment on frame - the position is already TOP-LEFT
        Text(content.text ?? "")
            .font(fontForContent())
            .foregroundColor(Color(hex: content.color ?? "#ffffff"))
            .multilineTextAlignment(alignmentForString(content.align))
            .lineLimit(nil)
            .frame(maxWidth: maxWidth, alignment: .leading)
    }
    
    /// Creates the font with proper size and weight, scaled proportionally
    private func fontForContent() -> Font {
        // Use custom fontSize if set, otherwise use variant-based size
        let baseSize: CGFloat
        if let customSize = content.fontSizeValue {
            baseSize = customSize
        } else {
            baseSize = sizeForVariant(content.variant)
        }
        
        // Scale the font size proportionally to the device
        let scaledSize = baseSize * scaleFactor
        
        let weight = weightForString(content.fontWeight) ?? weightForVariant(content.variant)
        
        // Use system font with scaled size and weight
        return .system(size: scaledSize, weight: weight)
    }
    
    private func sizeForVariant(_ variant: String?) -> CGFloat {
        switch variant {
        case "h1": return 34
        case "h2": return 28
        case "h3": return 22
        case "caption": return 12
        case "label": return 14
        default: return 16
        }
    }
    
    private func weightForVariant(_ variant: String?) -> Font.Weight {
        switch variant {
        case "h1", "h2": return .bold
        case "h3": return .semibold
        case "label": return .medium
        default: return .regular
        }
    }
    
    private func weightForString(_ weight: String?) -> Font.Weight? {
        switch weight {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "normal", "regular": return .regular
        default: return nil
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
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        Text(content.icon ?? "")
            .font(.system(size: sizeForString(content.size) * scaleFactor))
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
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
    private var isAuthButton: Bool {
        content.preset?.hasPrefix("sign-in-") == true
    }
    
    var body: some View {
        Button(action: {
            let action = content.action ?? .next
            onTap(action)
        }) {
            if isAuthButton {
                // Auth buttons: icon left, centered text, spacer right
                HStack(spacing: 12 * scaleFactor) {
                    authIcon
                        .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
                    
                    Text(content.text ?? "Continue")
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                        .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                        .frame(maxWidth: .infinity)
                    
                    // Spacer to balance the icon
                    Color.clear
                        .frame(width: 24 * scaleFactor, height: 24 * scaleFactor)
                }
                .padding(.horizontal, 20 * scaleFactor)
                .padding(.vertical, 16 * scaleFactor)
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .background(Color(hex: content.backgroundColor ?? "#10b981"))
                .cornerRadius(CGFloat(content.borderRadius ?? 9999) * scaleFactor)
            } else {
                // Regular button
                HStack(spacing: 8 * scaleFactor) {
                    if let icon = content.icon, content.iconPosition != "right" {
                        Text(icon)
                            .font(.system(size: 20 * scaleFactor))
                    }
                    
                    Text(content.text ?? "Continue")
                        .font(.system(size: 17 * scaleFactor, weight: .semibold))
                        .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                    
                    if let icon = content.icon, content.iconPosition == "right" {
                        Text(icon)
                            .font(.system(size: 20 * scaleFactor))
                    }
                }
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .padding(.horizontal, 24 * scaleFactor)
                .padding(.vertical, 16 * scaleFactor)
                .background(Color(hex: content.backgroundColor ?? "#10b981"))
                .cornerRadius(CGFloat(content.borderRadius ?? 12) * scaleFactor)
            }
        }
    }
    
    @ViewBuilder
    private var authIcon: some View {
        switch content.preset {
        case "sign-in-apple":
            AppleLogoView()
        case "sign-in-google":
            GoogleLogoView()
        case "sign-in-email":
            EmailIconView(color: Color(hex: content.textColor ?? "#ffffff"))
        default:
            EmptyView()
        }
    }
}

// MARK: - Auth Provider Icons

/// Apple logo for Sign in with Apple button
struct AppleLogoView: View {
    var body: some View {
        Image(systemName: "apple.logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundColor(.white)
    }
}

/// Google logo for Sign in with Google button (colored G)
struct GoogleLogoView: View {
    var body: some View {
        // Custom Google "G" logo using shapes
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Blue arc (right side)
                Circle()
                    .trim(from: 0.625, to: 0.875)
                    .stroke(Color(hex: "#4285F4"), lineWidth: size * 0.2)
                    .frame(width: size * 0.8, height: size * 0.8)
                
                // Green arc (bottom)
                Circle()
                    .trim(from: 0.375, to: 0.625)
                    .stroke(Color(hex: "#34A853"), lineWidth: size * 0.2)
                    .frame(width: size * 0.8, height: size * 0.8)
                
                // Yellow arc (bottom-left)
                Circle()
                    .trim(from: 0.25, to: 0.375)
                    .stroke(Color(hex: "#FBBC05"), lineWidth: size * 0.2)
                    .frame(width: size * 0.8, height: size * 0.8)
                
                // Red arc (top-left and top)
                Circle()
                    .trim(from: 0.875, to: 1.0)
                    .stroke(Color(hex: "#EA4335"), lineWidth: size * 0.2)
                    .frame(width: size * 0.8, height: size * 0.8)
                
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(Color(hex: "#EA4335"), lineWidth: size * 0.2)
                    .frame(width: size * 0.8, height: size * 0.8)
                
                // Blue bar (horizontal line of G)
                Rectangle()
                    .fill(Color(hex: "#4285F4"))
                    .frame(width: size * 0.5, height: size * 0.2)
                    .offset(x: size * 0.1)
            }
        }
        .frame(width: 24, height: 24)
    }
}

/// Email icon for email sign-in button
struct EmailIconView: View {
    let color: Color
    
    var body: some View {
        Image(systemName: "envelope")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 16)
            .foregroundColor(color)
    }
}

struct SpacerBlockView: View {
    let content: BlockContent
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        let baseHeight: CGFloat = {
            switch content.height {
            case .number(let value):
                return CGFloat(value)
            case .string(let str):
                return CGFloat(Int(str) ?? 16)
            case .none:
                return 16
            }
        }()
        Spacer().frame(height: baseHeight * scaleFactor)
    }
}

struct ImageBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        if let src = content.src, let url = URL(string: src) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: maxWidth ?? .infinity)
            .cornerRadius(CGFloat(content.borderRadius ?? 0) * scaleFactor)
        }
    }
}

struct DividerBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        Rectangle()
            .fill(Color(hex: content.color ?? "#333333"))
            .frame(height: CGFloat(content.thickness ?? 1) * scaleFactor)
            .frame(maxWidth: maxWidth ?? .infinity)
    }
}

struct InputBlockView: View {
    let content: BlockContent
    var styling: BlockStyling?
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    @State private var text: String = ""
    
    /// Border radius - prioritize styling.borderRadius, fall back to content.borderRadius, then default 15
    private var borderRadius: CGFloat {
        let radius = styling?.borderRadius ?? content.borderRadius ?? 15
        return CGFloat(radius) * scaleFactor
    }
    
    /// Background color - prioritize styling.backgroundColor, fall back to content.backgroundColor
    private var backgroundColor: Color {
        let hex = styling?.backgroundColor ?? content.backgroundColor ?? "#1e293b"
        return Color(hex: hex)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            // Label
            if let label = content.label {
                Text(label)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundColor(Color(hex: content.color ?? "#ffffff"))
            }
            
            // Text field
            TextField(content.placeholder ?? "", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16 * scaleFactor))
                .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                .padding(.horizontal, 16 * scaleFactor)
                .padding(.vertical, 14 * scaleFactor)
                .background(backgroundColor)
                .cornerRadius(borderRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: borderRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
    }
}

struct ChecklistBlockView: View {
    let content: BlockContent
    let onButtonTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    @State private var selectedItems: Set<String> = []
    
    private var activeColor: Color {
        Color(hex: content.activeColor ?? "#10b981")
    }
    
    private var checklistStyle: String {
        content.checklistStyle ?? content.style ?? "pills"  // Default to 'pills' to match editor
    }
    
    private var columns: Int {
        content.columns ?? 1
    }
    
    // Styling options with defaults - scaled by scaleFactor
    private var fontSize: CGFloat {
        CGFloat(content.fontSize ?? 14) * scaleFactor
    }
    
    private var itemPadding: CGFloat {
        CGFloat(content.itemPadding ?? 12) * scaleFactor
    }
    
    private var itemGap: CGFloat {
        CGFloat(content.itemGap ?? 8) * scaleFactor
    }
    
    private var borderRadius: CGFloat {
        CGFloat(content.itemBorderRadius ?? content.borderRadius ?? 12) * scaleFactor
    }
    
    var body: some View {
        Group {
            switch checklistStyle {
            case "pills":
                pillsLayout
            case "cards":
                cardsLayout
            default:
                listLayout
            }
        }
        // Use fixed width (matching web's 345px) to ensure consistent rendering
        // The maxWidth passed from parent is already scaled (345 * uniformScale)
        .frame(width: maxWidth, alignment: .leading)
    }
    
    // MARK: - List Style (default)
    
    private var listLayout: some View {
        VStack(spacing: itemGap) {
            if let items = content.items {
                ForEach(items) { item in
                    ChecklistListItemView(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        activeColor: activeColor,
                        fontSize: fontSize,
                        padding: itemPadding,
                        cornerRadius: borderRadius,
                        onToggle: { toggleItem(item) }
                    )
                }
            }
        }
    }
    
    // MARK: - Pills Style
    
    private var pillsLayout: some View {
        Group {
            if columns == 2 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: itemGap) {
                    if let items = content.items {
                        ForEach(items) { item in
                            ChecklistPillView(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                activeColor: activeColor,
                                fontSize: fontSize,
                                padding: itemPadding,
                                cornerRadius: borderRadius,
                                onToggle: { toggleItem(item) }
                            )
                        }
                    }
                }
            } else {
                // Wrap layout for single column
                FlexiblePillsView(
                    items: content.items ?? [],
                    selectedItems: selectedItems,
                    activeColor: activeColor,
                    fontSize: fontSize,
                    padding: itemPadding,
                    cornerRadius: borderRadius,
                    itemGap: itemGap,
                    onToggle: toggleItem
                )
            }
        }
    }
    
    // MARK: - Cards Style
    
    private var cardsLayout: some View {
        Group {
            if columns == 2 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: itemGap) {
                    if let items = content.items {
                        ForEach(items) { item in
                            ChecklistCardView(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                activeColor: activeColor,
                                fontSize: fontSize,
                                padding: itemPadding,
                                cornerRadius: borderRadius,
                                onToggle: { toggleItem(item) }
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: itemGap) {
                    if let items = content.items {
                        ForEach(items) { item in
                            ChecklistCardView(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                activeColor: activeColor,
                                fontSize: fontSize,
                                padding: itemPadding,
                                cornerRadius: borderRadius,
                                onToggle: { toggleItem(item) }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func toggleItem(_ item: ChecklistItem) {
        logger.info("🔧 [Checklist] toggleItem called for: \(item.label)")
        logger.info("🔧 [Checklist] Current selectedItems: \(selectedItems.description)")
        logger.info("🔧 [Checklist] allowMultiple: \(content.allowMultiple ?? false)")
        logger.info("🔧 [Checklist] autoAdvance: \(content.autoAdvance ?? true)")
        logger.info("🔧 [Checklist] action: \(String(describing: content.action))")
        print("🔧 [Checklist] toggleItem called for: \(item.label)")
        print("🔧 [Checklist] Current selectedItems: \(selectedItems)")
        print("🔧 [Checklist] allowMultiple: \(content.allowMultiple ?? false)")
        print("🔧 [Checklist] autoAdvance: \(content.autoAdvance ?? true)")
        print("🔧 [Checklist] action: \(String(describing: content.action))")
        
        if content.allowMultiple == true {
            // Multiple selection
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
                print("🔧 [Checklist] Removed item from selection")
            } else {
                // Check max selections
                if let max = content.maxSelections, selectedItems.count >= max {
                    print("🔧 [Checklist] Max selections reached (\(max))")
                    return
                }
                selectedItems.insert(item.id)
                logger.info("🔧 [Checklist] Added item to selection")
                print("🔧 [Checklist] Added item to selection")
            }
        } else {
            // Single selection
            selectedItems = [item.id]
            logger.info("🔧 [Checklist] Single selection - set to: \(item.id)")
            print("🔧 [Checklist] Single selection - set to: \(item.id)")
            
            // Auto-advance on single selection - default to true if not explicitly set to false
            // This is the expected UX: select an option and automatically proceed
            let shouldAutoAdvance = content.autoAdvance ?? true
            let action = content.action ?? .next
            logger.info("🔧 [Checklist] shouldAutoAdvance=\(shouldAutoAdvance), action=\(String(describing: action))")
            print("🔧 [Checklist] shouldAutoAdvance=\(shouldAutoAdvance), action=\(action)")
            
            if shouldAutoAdvance {
                // Trigger the action after a brief delay for visual feedback
                logger.info("🔧 [Checklist] Scheduling action trigger in 0.3s...")
                print("🔧 [Checklist] Scheduling action trigger in 0.3s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    logger.info("🔧 [Checklist] ⚡ TRIGGERING ACTION NOW: \(String(describing: action))")
                    print("🔧 [Checklist] ⚡ TRIGGERING ACTION NOW: \(action)")
                    onButtonTap(action)
                }
            } else {
                logger.info("🔧 [Checklist] autoAdvance is false, not triggering action")
                print("🔧 [Checklist] autoAdvance is false, not triggering action")
            }
        }
    }
}

// MARK: - List Item View (matches editor's list style)

struct ChecklistListItemView: View {
    let item: ChecklistItem
    let isSelected: Bool
    let activeColor: Color
    var fontSize: CGFloat = 16
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 12
    let onToggle: () -> Void
    
    private var indicatorSize: CGFloat {
        max(16, fontSize + 4)
    }
    
    var body: some View {
        Button(action: {
            logger.info("🔧 [ChecklistItem] Tapped item: \(item.label)")
            print("🔧 [ChecklistItem] Tapped item: \(item.label)")
            onToggle()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Circular indicator on the LEFT (matches editor)
                ZStack {
                    Circle()
                        .stroke(isSelected ? activeColor : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: indicatorSize, height: indicatorSize)
                    
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: indicatorSize, height: indicatorSize)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: fontSize * 0.6, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: indicatorSize, height: indicatorSize)
                
                // Text on the RIGHT of the circle - allow multi-line wrapping
                Text(item.label)
                    .font(.system(size: fontSize))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil) // Allow unlimited lines
                    .fixedSize(horizontal: false, vertical: true) // Wrap horizontally, expand vertically
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? activeColor.opacity(0.12) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isSelected ? activeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pill View (matches editor's pills style)

struct ChecklistPillView: View {
    let item: ChecklistItem
    let isSelected: Bool
    let activeColor: Color
    var fontSize: CGFloat = 14
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 9999
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(item.label)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.8))
                .lineLimit(nil) // Allow multi-line if needed
                .multilineTextAlignment(.center)
                .padding(.horizontal, padding * 1.5)
                .padding(.vertical, padding * 0.7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius == 9999 ? 9999 : cornerRadius)
                        .fill(isSelected ? activeColor : Color.white.opacity(0.1))
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .shadow(color: isSelected ? activeColor.opacity(0.4) : .clear, radius: 7, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Flexible Pills Layout (for wrapping)

struct FlexiblePillsView: View {
    let items: [ChecklistItem]
    let selectedItems: Set<String>
    let activeColor: Color
    var fontSize: CGFloat = 14
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 9999
    var itemGap: CGFloat = 8
    let onToggle: (ChecklistItem) -> Void
    
    var body: some View {
        // Stack pills vertically (matching web's flex-col layout for single column)
        VStack(spacing: itemGap) {
            ForEach(items) { item in
                ChecklistPillView(
                    item: item,
                    isSelected: selectedItems.contains(item.id),
                    activeColor: activeColor,
                    fontSize: fontSize,
                    padding: padding,
                    cornerRadius: cornerRadius,
                    onToggle: { onToggle(item) }
                )
            }
        }
    }
}

// MARK: - Card View (matches editor's cards style)

struct ChecklistCardView: View {
    let item: ChecklistItem
    let isSelected: Bool
    let activeColor: Color
    var fontSize: CGFloat = 16
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    let onToggle: () -> Void
    
    private var indicatorSize: CGFloat {
        max(16, fontSize + 4)
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                // Circular indicator on the LEFT (matches editor)
                ZStack {
                    Circle()
                        .stroke(isSelected ? activeColor : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: indicatorSize, height: indicatorSize)
                    
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: indicatorSize, height: indicatorSize)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: fontSize * 0.6, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: indicatorSize, height: indicatorSize)
                
                // Text on the RIGHT of the circle - allow multi-line wrapping
                Text(item.label)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil) // Allow unlimited lines
                    .fixedSize(horizontal: false, vertical: true) // Wrap horizontally, expand vertically
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? activeColor.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? activeColor : Color.white.opacity(0.1), lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct VideoBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
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
                    .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 24 * scaleFactor))
                    .foregroundColor(Color(hex: "#0f172a"))
                    .offset(x: 2 * scaleFactor)
            }
            .frame(maxWidth: maxWidth ?? .infinity)
            .frame(height: 200 * scaleFactor)
            .cornerRadius(CGFloat(content.borderRadius ?? 12) * scaleFactor)
            .clipped()
        }
    }
}

struct ProgressBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    /// Scale factor for proportional sizing
    var scaleFactor: CGFloat = 1.0
    
    var body: some View {
        // Simple progress bar placeholder
        // The actual progress would be controlled by the parent view
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4 * scaleFactor)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8 * scaleFactor)
                
                RoundedRectangle(cornerRadius: 4 * scaleFactor)
                    .fill(Color(hex: content.color ?? "#10b981"))
                    .frame(width: geometry.size.width * 0.5, height: 8 * scaleFactor)
            }
        }
        .frame(height: 8 * scaleFactor)
        .frame(maxWidth: maxWidth ?? .infinity)
    }
}

// MARK: - Flow Progress View (renders flow-level progress indicator)

struct FlowProgressView: View {
    let indicator: FlowProgressIndicator
    let currentIndex: Int
    let totalScreens: Int
    
    private var fillColor: Color {
        Color(hex: indicator.fillColor ?? "#10b981")
    }
    
    private var trackColor: Color {
        Color(hex: indicator.trackColor ?? "rgba(255,255,255,0.2)")
    }
    
    // Calculate screen range
    private var rangeStart: Int {
        let start = indicator.startScreen ?? 0
        return max(0, min(start, totalScreens - 1))
    }
    
    private var rangeEnd: Int {
        let end = indicator.endScreen ?? (totalScreens - 1)
        return max(rangeStart, min(end, totalScreens - 1))
    }
    
    private var rangeSize: Int {
        rangeEnd - rangeStart + 1
    }
    
    // Only show indicator when currentIndex is within the range
    private var shouldShow: Bool {
        currentIndex >= rangeStart && currentIndex <= rangeEnd
    }
    
    // Calculate progress within the range
    private var clampedIndex: Int {
        max(rangeStart, min(currentIndex, rangeEnd))
    }
    
    private var relativeIndex: Int {
        clampedIndex - rangeStart
    }
    
    var body: some View {
        if !shouldShow {
            EmptyView()
        } else {
            switch indicator.variant {
            case .dots:
                dotsView
            case .bar:
                barView
            case .steps:
                stepsView
            case .minimal:
                minimalView
            case .none:
                dotsView // Default to dots
            }
        }
    }
    
    private var dotsView: some View {
        HStack(spacing: 6) {
            ForEach(0..<rangeSize, id: \.self) { i in
                let screenIndex = rangeStart + i
                let isCurrent = screenIndex == currentIndex
                let isCompleted = screenIndex < currentIndex
                Circle()
                    .fill(isCompleted || isCurrent ? fillColor : trackColor)
                    .frame(width: isCurrent ? 16 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
    }
    
    private var barView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(trackColor)
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .frame(width: geometry.size.width * CGFloat(relativeIndex + 1) / CGFloat(rangeSize), height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 20)
    }
    
    private var stepsView: some View {
        HStack(spacing: 4) {
            ForEach(0..<rangeSize, id: \.self) { i in
                let screenIndex = rangeStart + i
                let isCompleted = screenIndex < currentIndex
                let isCurrent = screenIndex == currentIndex
                let stepNumber = i + 1 // Step number within the range (1-based)
                
                ZStack {
                    Circle()
                        .stroke(isCompleted || isCurrent ? fillColor : trackColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    
                    if isCompleted {
                        Circle()
                            .fill(fillColor)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else if isCurrent {
                        Circle()
                            .fill(fillColor)
                            .frame(width: 24, height: 24)
                        
                        Text("\(stepNumber)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(stepNumber)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                
                if i < rangeSize - 1 {
                    Rectangle()
                        .fill(isCompleted ? fillColor : trackColor)
                        .frame(width: 20, height: 2)
                }
            }
        }
    }
    
    private var minimalView: some View {
        Text("\(relativeIndex + 1)/\(rangeSize)")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
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

