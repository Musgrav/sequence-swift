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
    
    // Check if blocks use absolute positioning
    private var hasAbsolutePositioning: Bool {
        screen.content.useBlocks == true && 
        screen.content.blocks?.contains { $0.position != nil } == true
    }
    
    var body: some View {
        ZStack {
            // Background - extends to screen edges
            backgroundView
                .ignoresSafeArea()
            
            // Content - respects safe area for absolute positioning
            GeometryReader { geometry in
                if hasAbsolutePositioning, let blocks = screen.content.blocks {
                    // Absolute positioning mode - BlocksContentView takes full safe area
                    // This matches the editor's canvas behavior exactly
                    BlocksContentView(blocks: blocks, onButtonTap: onButtonTap)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    // Standard VStack layout
                    VStack(spacing: 0) {
                        // Progress indicator
                        if totalScreens > 1 {
                            ProgressDots(total: totalScreens, current: currentIndex)
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                        } else {
                            Spacer().frame(height: 40)
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
                            .padding(.bottom, 20)
                        } else {
                            Spacer().frame(height: 20)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
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
    
    // Editor canvas dimensions (must match web/src/lib/device-constants.ts DESIGN_CANVAS)
    // iPhone 15/16 Pro dimensions in points
    private let editorCanvasWidth: CGFloat = 393
    private let editorCanvasHeight: CGFloat = 852
    
    // Check if any block has absolute positioning
    private var hasAbsolutePositioning: Bool {
        blocks.contains { $0.position != nil }
    }
    
    var body: some View {
        if hasAbsolutePositioning {
            // Use absolute positioning (ZStack) for free-form layouts
            // Position is the TOP-LEFT corner of the block in editor canvas coordinates
            GeometryReader { geometry in
                let scaleX = geometry.size.width / editorCanvasWidth
                let scaleY = geometry.size.height / editorCanvasHeight

                ZStack(alignment: .topLeading) {
                    ForEach(blocks.sorted(by: { $0.order < $1.order })) { block in
                        if let position = block.position {
                            // Scale positions from editor canvas (393×852) to device screen
                            let scaledX = position.x * scaleX
                            let scaledY = position.y * scaleY

                            // Get explicit width from styling if set (DimensionValue can be number or string)
                            let explicitWidth: CGFloat? = {
                                if let w = block.styling?.width {
                                    switch w {
                                    case .number(let n): return CGFloat(n) * scaleX
                                    case .string(_): return nil // 'auto' or 'full' - use intrinsic sizing
                                    }
                                }
                                return nil
                            }()

                            // Max width to prevent overflow off right edge
                            let maxWidth = geometry.size.width - scaledX - 8

                            BlockView(block: block, onButtonTap: onButtonTap, maxWidth: explicitWidth ?? maxWidth)
                                .fixedSize(horizontal: explicitWidth == nil, vertical: true)
                                .offset(x: scaledX, y: scaledY)
                        } else {
                            BlockView(block: block, onButtonTap: onButtonTap, maxWidth: nil)
                        }
                    }
                }
            }
        } else {
            // Fallback to VStack layout for legacy content
            VStack(spacing: 16) {
                ForEach(blocks.sorted(by: { $0.order < $1.order })) { block in
                    BlockView(block: block, onButtonTap: onButtonTap, maxWidth: nil)
                }
            }
        }
    }
}

struct BlockView: View {
    let block: ContentBlock
    let onButtonTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    
    var body: some View {
        switch block.type {
        case .text:
            TextBlockView(content: block.content, maxWidth: maxWidth)
        case .icon:
            IconBlockView(content: block.content)
        case .button:
            ButtonBlockView(content: block.content, onTap: onButtonTap, maxWidth: maxWidth)
        case .spacer:
            SpacerBlockView(content: block.content)
        case .image:
            ImageBlockView(content: block.content, maxWidth: maxWidth)
        case .divider:
            DividerBlockView(content: block.content, maxWidth: maxWidth)
        case .input:
            InputBlockView(content: block.content, styling: block.styling, maxWidth: maxWidth)
        case .checklist:
            ChecklistBlockView(content: block.content, onButtonTap: onButtonTap, maxWidth: maxWidth)
        case .video:
            VideoBlockView(content: block.content, maxWidth: maxWidth)
        case .slider:
            SliderBlockView(content: block.content, maxWidth: maxWidth)
        case .progress:
            ProgressBlockView(content: block.content, maxWidth: maxWidth)
        case .loadingIndicator:
            LoadingIndicatorBlockView(content: block.content, maxWidth: maxWidth)
        case .featureCard:
            FeatureCardBlockView(content: block.content, maxWidth: maxWidth)
        case .scrollContainer:
            // Scroll container needs special handling for child blocks
            EmptyView()
        case .lottie, .custom, .unknown:
            // Custom/unknown blocks require native implementation
            EmptyView()
        }
    }
}

struct TextBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?

    // Computed properties for font configuration
    // Sizes match Tailwind CSS: h1=text-3xl(30), h2=text-2xl(24), h3=text-xl(20), body=text-base(16), caption=text-sm(14), label=text-xs(12)
    private var fontSize: CGFloat {
        // Use explicit fontSize if provided, otherwise use variant-based size
        if let size = content.fontSize {
            return CGFloat(size)
        }
        switch content.variant {
        case "h1": return 30  // text-3xl
        case "h2": return 24  // text-2xl
        case "h3": return 20  // text-xl
        case "caption": return 14  // text-sm
        case "label": return 12  // text-xs
        default: return 16 // body = text-base
        }
    }

    private var fontWeight: Font.Weight {
        // Use explicit fontWeight if provided, otherwise use variant-based weight
        if let weight = content.fontWeight {
            switch weight {
            case "bold": return .bold
            case "semibold": return .semibold
            case "medium": return .medium
            case "light": return .light
            case "normal", "regular": return .regular
            default: return .regular
            }
        }
        // Variant-based defaults
        switch content.variant {
        case "h1", "h2": return .bold
        case "h3": return .semibold
        case "label": return .medium
        default: return .regular
        }
    }

    private var textColor: Color {
        // Use color or textColor property
        if let colorHex = content.color ?? content.textColor {
            return Color(hex: colorHex)
        }
        return .white
    }

    private var textAlignment: TextAlignment {
        switch content.align {
        case "left": return .leading
        case "right": return .trailing
        default: return .center
        }
    }

    private var frameAlignment: Alignment {
        switch content.align {
        case "left": return .leading
        case "right": return .trailing
        default: return .center
        }
    }

    var body: some View {
        let _ = print("🔍 [TextBlockView] text='\(content.text ?? "nil")' variant='\(content.variant ?? "nil")' color='\(content.color ?? "nil")' fontSize=\(fontSize) fontWeight=\(fontWeight)")
        Text(content.text ?? "")
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(textColor)
            .multilineTextAlignment(textAlignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxWidth ?? .infinity, alignment: frameAlignment)
    }
}

struct IconBlockView: View {
    let content: BlockContent
    
    var body: some View {
        Text(content.icon ?? "")
            .font(.system(size: sizeForDimension(content.size)))
    }

    private func sizeForDimension(_ size: DimensionValue?) -> CGFloat {
        guard let size = size else { return 48 }
        switch size {
        case .string(let str):
            switch str {
            case "sm": return 24
            case "md": return 32
            case "lg": return 48
            case "xl": return 64
            case "2xl": return 80
            default: return 48
            }
        case .number(let num):
            return CGFloat(num)
        }
    }
}

struct ButtonBlockView: View {
    let content: BlockContent
    let onTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?

    private var isAuthButton: Bool {
        content.preset?.hasPrefix("sign-in-") == true
    }

    private var isGhostVariant: Bool {
        content.variant == "ghost" || content.variant == "link"
    }

    private var isOutlineVariant: Bool {
        content.variant == "outline" || content.variant == "secondary"
    }

    // Button size - 'sm', 'md', 'lg' from DimensionValue
    private var buttonSize: String {
        if let sizeValue = content.size {
            switch sizeValue {
            case .string(let str): return str
            default: return "md"
            }
        }
        return "md"
    }

    // Size-based padding (uses explicit padding if set, otherwise size-based defaults)
    private var horizontalPadding: CGFloat {
        if let explicit = content.paddingHorizontal { return CGFloat(explicit) }
        switch buttonSize {
        case "sm": return 16
        case "lg": return 32
        default: return 24 // md
        }
    }

    private var verticalPadding: CGFloat {
        if let explicit = content.paddingVertical { return CGFloat(explicit) }
        switch buttonSize {
        case "sm": return 8
        case "lg": return 16
        default: return 12 // md
        }
    }

    private var fontSize: CGFloat {
        if let explicit = content.fontSize { return CGFloat(explicit) }
        switch buttonSize {
        case "sm": return 14
        case "lg": return 18
        default: return 16 // md
        }
    }

    private var iconSize: CGFloat {
        switch buttonSize {
        case "sm": return 16
        case "lg": return 24
        default: return 20 // md
        }
    }

    var body: some View {
        Button(action: {
            let action = content.action ?? .next
            onTap(action)
        }) {
            if isAuthButton {
                // Auth buttons: icon left, centered text, spacer right
                HStack(spacing: 12) {
                    authIcon
                        .frame(width: 24, height: 24)

                    Text(content.text ?? "Continue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                        .frame(maxWidth: .infinity)

                    // Spacer to balance the icon
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .background(Color(hex: content.backgroundColor ?? "#10b981"))
                .cornerRadius(CGFloat(content.borderRadius ?? 9999))
            } else if isGhostVariant {
                // Ghost/link button - no background, just text
                HStack(spacing: 8) {
                    if let icon = content.icon, content.iconPosition != "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }

                    Text(content.text ?? "Continue")
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(Color(hex: content.textColor ?? content.color ?? "#ffffff"))

                    if let icon = content.icon, content.iconPosition == "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            } else if isOutlineVariant {
                // Outline button - border only, no fill
                HStack(spacing: 8) {
                    if let icon = content.icon, content.iconPosition != "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }

                    Text(content.text ?? "Continue")
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(Color(hex: content.textColor ?? content.backgroundColor ?? "#ffffff"))

                    if let icon = content.icon, content.iconPosition == "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }
                }
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(content.borderRadius ?? 12))
                        .stroke(Color(hex: content.backgroundColor ?? "#ffffff"), lineWidth: 2)
                )
            } else {
                // Primary/default button - filled background
                HStack(spacing: 8) {
                    if let icon = content.icon, content.iconPosition != "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }

                    Text(content.text ?? "Continue")
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))

                    if let icon = content.icon, content.iconPosition == "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }
                }
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(Color(hex: content.backgroundColor ?? "#10b981"))
                .cornerRadius(CGFloat(content.borderRadius ?? 12))
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
    var maxWidth: CGFloat?
    
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
            .cornerRadius(CGFloat(content.borderRadius ?? 0))
        }
    }
}

struct DividerBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    
    var body: some View {
        Rectangle()
            .fill(Color(hex: content.color ?? "#333333"))
            .frame(height: CGFloat(content.thickness ?? 1))
            .frame(maxWidth: maxWidth ?? .infinity)
    }
}

struct InputBlockView: View {
    let content: BlockContent
    var styling: BlockStyling?
    var maxWidth: CGFloat?
    @State private var text: String = ""

    // Use styling if available, otherwise fall back to content properties
    private var backgroundColor: Color {
        if let bg = styling?.backgroundColor ?? content.backgroundColor {
            return Color(hex: bg)
        }
        return Color(hex: "#1e293b")
    }

    private var borderRadius: CGFloat {
        CGFloat(styling?.borderRadius ?? content.borderRadius ?? 12)
    }

    private var borderColor: Color {
        if let bc = styling?.borderColor {
            return Color(hex: bc)
        }
        return Color.white.opacity(0.2)
    }

    private var borderWidth: CGFloat {
        CGFloat(styling?.borderWidth ?? 1)
    }

    private var textColor: Color {
        if let tc = content.textColor ?? content.color {
            return Color(hex: tc)
        }
        return .white
    }

    private var placeholderColor: Color {
        if let pc = content.placeholderColor {
            return Color(hex: pc)
        }
        return Color.white.opacity(0.5)
    }

    var body: some View {
        let _ = print("🔍 [InputBlockView] placeholder='\(content.placeholder ?? "nil")' bgColor='\(styling?.backgroundColor ?? content.backgroundColor ?? "default")' borderRadius=\(borderRadius)")
        VStack(alignment: .leading, spacing: 8) {
            // Label
            if let label = content.label {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
            }

            // Text field
            TextField(content.placeholder ?? "", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(backgroundColor)
                .cornerRadius(borderRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: borderRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
    }
}

struct ChecklistBlockView: View {
    let content: BlockContent
    let onButtonTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    @State private var selectedItems: Set<String> = []
    
    private var activeColor: Color {
        Color(hex: content.activeColor ?? "#10b981")
    }
    
    private var checklistStyle: String {
        content.checklistStyle ?? content.style ?? "list"
    }
    
    private var columns: Int {
        content.columns ?? 1
    }
    
    // Styling options with defaults
    private var fontSize: CGFloat {
        CGFloat(content.fontSize ?? 14)
    }
    
    private var itemPadding: CGFloat {
        CGFloat(content.itemPadding ?? 12)
    }
    
    private var itemGap: CGFloat {
        CGFloat(content.itemGap ?? 8)
    }
    
    private var borderRadius: CGFloat {
        CGFloat(content.itemBorderRadius ?? content.borderRadius ?? 12)
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
        .frame(maxWidth: maxWidth ?? .infinity)
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
        if content.allowMultiple == true {
            // Multiple selection
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                // Check max selections
                if let max = content.maxSelections, selectedItems.count >= max {
                    return
                }
                selectedItems.insert(item.id)
            }
        } else {
            // Single selection
            selectedItems = [item.id]
            
            // Auto-advance on single selection - default to true if not explicitly set to false
            // This is the expected UX: select an option and automatically proceed
            let shouldAutoAdvance = content.autoAdvance ?? true
            if shouldAutoAdvance {
                // Trigger the action after a brief delay for visual feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let action = content.action ?? .next
                    onButtonTap(action)
                }
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
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Circular indicator (matches editor exactly)
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
                
                Text(item.label)
                    .font(.system(size: fontSize))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
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
        // Simple horizontal wrapping using HStack + VStack
        VStack(spacing: itemGap) {
            HStack(spacing: itemGap) {
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
                    .fixedSize()
                }
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
                Text(item.label)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Circular indicator in top-right
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
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .frame(maxWidth: maxWidth ?? .infinity)
            .frame(height: 200)
            .cornerRadius(CGFloat(content.borderRadius ?? 12))
            .clipped()
        }
    }
}

struct ProgressBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?

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
        .frame(maxWidth: maxWidth ?? .infinity)
    }
}

// MARK: - Slider Block

struct SliderBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?

    private var minValue: Int { content.min ?? 0 }
    private var maxValue: Int { content.max ?? 100 }
    private var currentValue: Int { content.defaultValue ?? ((minValue + maxValue) / 2) }

    private var fillColor: Color { Color(hex: content.fillColor ?? "#f97316") }
    private var trackColor: Color { Color(hex: content.trackColor ?? "rgba(200, 200, 200, 0.3)") }
    private var thumbColor: Color { Color(hex: content.thumbColor ?? "#ffffff") }

    private var thumbSizeValue: CGFloat { CGFloat(content.thumbSize ?? 32) }
    private var trackHeightValue: CGFloat { CGFloat(content.trackHeight ?? 12) }

    private var percentage: CGFloat {
        guard maxValue > minValue else { return 0 }
        return CGFloat(currentValue - minValue) / CGFloat(maxValue - minValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Value display
            if content.showValue != false {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    if let prefix = content.valuePrefix {
                        Text(prefix)
                            .font(.system(size: CGFloat(content.valueFontSize ?? 48)))
                    }
                    Text("\(currentValue)")
                        .font(.system(size: CGFloat(content.valueFontSize ?? 48), weight: fontWeight(content.valueFontWeight)))
                        .foregroundColor(Color(hex: content.valueColor ?? "#000000"))
                    if let suffix = content.valueSuffix {
                        Text(suffix)
                            .font(.system(size: CGFloat(content.suffixFontSize ?? 24)))
                            .foregroundColor(Color(hex: content.valueColor ?? "#000000").opacity(0.7))
                    }
                }
            }

            // Slider track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: trackHeightValue / 2)
                        .fill(trackColor)
                        .frame(height: trackHeightValue)

                    // Filled portion
                    RoundedRectangle(cornerRadius: trackHeightValue / 2)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * percentage, height: trackHeightValue)

                    // Thumb
                    Circle()
                        .fill(thumbColor)
                        .frame(width: thumbSizeValue, height: thumbSizeValue)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .offset(x: (geometry.size.width - thumbSizeValue) * percentage)
                }
                .frame(height: max(trackHeightValue, thumbSizeValue))
            }
            .frame(height: max(trackHeightValue, thumbSizeValue))

            // Min/Max labels
            if content.showMinMax != false {
                HStack {
                    Text("\(minValue)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: content.labelColor ?? "rgba(0, 0, 0, 0.5)"))
                    Spacer()
                    Text("\(maxValue)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: content.labelColor ?? "rgba(0, 0, 0, 0.5)"))
                }
            }
        }
        .frame(maxWidth: maxWidth ?? .infinity)
    }

    private func fontWeight(_ weight: String?) -> Font.Weight {
        switch weight {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        default: return .bold
        }
    }
}

// MARK: - Loading Indicator Block

struct LoadingIndicatorBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?

    @State private var progress: CGFloat = 0.34 // Static preview

    private var fillColor: Color { Color(hex: content.fillColor ?? "#f97316") }
    private var trackColor: Color { Color(hex: content.trackColor ?? "#e5e5e5") }
    private var size: CGFloat { CGFloat(content.thumbSize ?? 120) } // Reusing thumbSize for circle size
    private var strokeWidth: CGFloat { CGFloat(content.trackHeight ?? 8) }

    var body: some View {
        VStack(spacing: 16) {
            // Circular progress indicator
            ZStack {
                // Track
                Circle()
                    .stroke(trackColor, lineWidth: strokeWidth)

                // Progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(fillColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Percentage
                if content.showValue != false {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: CGFloat(content.valueFontSize ?? 32), weight: .medium))
                        .foregroundColor(Color(hex: content.valueColor ?? "#1a1a1a"))
                }
            }
            .frame(width: size, height: size)
        }
        .frame(maxWidth: maxWidth ?? .infinity)
    }
}

// MARK: - Feature Card Block

struct FeatureCardBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Headline (using text property)
            if let headline = content.text {
                Text(headline)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: content.color ?? "#000000"))
            }
        }
        .padding(24)
        .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
        .background(Color(hex: content.backgroundColor ?? "#ffffff"))
        .cornerRadius(CGFloat(content.borderRadius ?? 16))
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
    /// Initialize Color from hex string (#fff, #ffffff, #ffffffff) or rgba/rgb string
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespaces)

        // Handle rgba(r, g, b, a) format
        if trimmed.lowercased().hasPrefix("rgba(") {
            let values = trimmed
                .dropFirst(5) // Remove "rgba("
                .dropLast()   // Remove ")"
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            if values.count >= 4,
               let r = Double(values[0]),
               let g = Double(values[1]),
               let b = Double(values[2]),
               let a = Double(values[3]) {
                self.init(
                    .sRGB,
                    red: r / 255,
                    green: g / 255,
                    blue: b / 255,
                    opacity: a
                )
                return
            }
        }

        // Handle rgb(r, g, b) format
        if trimmed.lowercased().hasPrefix("rgb(") {
            let values = trimmed
                .dropFirst(4) // Remove "rgb("
                .dropLast()   // Remove ")"
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            if values.count >= 3,
               let r = Double(values[0]),
               let g = Double(values[1]),
               let b = Double(values[2]) {
                self.init(
                    .sRGB,
                    red: r / 255,
                    green: g / 255,
                    blue: b / 255,
                    opacity: 1.0
                )
                return
            }
        }

        // Handle hex format
        let hex = trimmed.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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

