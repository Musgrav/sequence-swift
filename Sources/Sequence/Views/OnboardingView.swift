// Sequence SwiftUI Views

import SwiftUI

// MARK: - Variable Interpolation

/// Replaces {fieldName} patterns in text with values from collectedData
/// Matches the web's text-template.ts interpolateText function
func interpolateText(_ text: String, with data: [String: String]) -> String {
    guard text.contains("{") else { return text }

    var result = text
    // Pattern matches {fieldName} - single curly braces
    let pattern = try! NSRegularExpression(pattern: "\\{([^}]+)\\}", options: [])
    let range = NSRange(text.startIndex..., in: text)

    // Process matches in reverse order to preserve indices
    let matches = pattern.matches(in: text, options: [], range: range).reversed()
    for match in matches {
        guard let fieldNameRange = Range(match.range(at: 1), in: text),
              let fullMatchRange = Range(match.range, in: result) else { continue }

        let fieldName = String(text[fieldNameRange]).trimmingCharacters(in: .whitespaces)

        // Look up value in collectedData
        if let value = data[fieldName], !value.isEmpty {
            result.replaceSubrange(fullMatchRange, with: value)
        }
        // If not found, keep the original {fieldName} placeholder
    }

    return result
}

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

    // Collected data from input fields for variable substitution
    @State private var collectedData: [String: String] = [:]

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
                    BlocksContentView(
                        blocks: blocks,
                        collectedData: $collectedData,
                        onButtonTap: onButtonTap
                    )
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
                            BlocksContentView(
                                blocks: blocks,
                                collectedData: $collectedData,
                                onButtonTap: onButtonTap
                            )
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
    @Binding var collectedData: [String: String]
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
                // Use NON-UNIFORM scaling (same as web FlowRenderer) to fill viewport
                // This stretches content to fill the entire device screen
                let scaleX = geometry.size.width / editorCanvasWidth
                let scaleY = geometry.size.height / editorCanvasHeight
                let _ = print("🔍 [BlocksContentView] geometry=\(geometry.size.width)x\(geometry.size.height) scaleX=\(scaleX) scaleY=\(scaleY)")

                ZStack(alignment: .topLeading) {
                    ForEach(blocks.sorted(by: { $0.order < $1.order })) { block in
                        if let position = block.position {
                            // Scale positions using separate scaleX and scaleY (non-uniform)
                            // X positions scale by scaleX, Y positions scale by scaleY
                            let scaledX = position.x * scaleX
                            let scaledY = position.y * scaleY
                            let _ = print("🔍 [Block \(block.type)] position=(\(position.x),\(position.y)) -> scaled=(\(scaledX),\(scaledY))")

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

                            BlockView(
                                block: block,
                                collectedData: $collectedData,
                                onButtonTap: onButtonTap,
                                maxWidth: explicitWidth ?? maxWidth,
                                scaleX: scaleX,
                                scaleY: scaleY
                            )
                            .fixedSize(horizontal: explicitWidth == nil, vertical: true)
                            .offset(x: scaledX, y: scaledY)
                        } else {
                            BlockView(
                                block: block,
                                collectedData: $collectedData,
                                onButtonTap: onButtonTap,
                                maxWidth: nil,
                                scaleX: 1.0,
                                scaleY: 1.0
                            )
                        }
                    }
                }
            }
        } else {
            // Fallback to VStack layout for legacy content
            VStack(spacing: 16) {
                ForEach(blocks.sorted(by: { $0.order < $1.order })) { block in
                    BlockView(
                        block: block,
                        collectedData: $collectedData,
                        onButtonTap: onButtonTap,
                        maxWidth: nil,
                        scaleX: 1.0,
                        scaleY: 1.0
                    )
                }
            }
        }
    }
}

struct BlockView: View {
    let block: ContentBlock
    @Binding var collectedData: [String: String]
    let onButtonTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    var body: some View {
        switch block.type {
        case .text:
            TextBlockView(content: block.content, collectedData: collectedData, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .icon:
            IconBlockView(content: block.content, scaleX: scaleX, scaleY: scaleY)
        case .button:
            ButtonBlockView(content: block.content, styling: block.styling, collectedData: collectedData, onTap: onButtonTap, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .spacer:
            SpacerBlockView(content: block.content, scaleY: scaleY)
        case .image:
            ImageBlockView(content: block.content, styling: block.styling, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .divider:
            DividerBlockView(content: block.content, maxWidth: maxWidth, scaleY: scaleY)
        case .input:
            InputBlockView(
                content: block.content,
                styling: block.styling,
                collectedData: $collectedData,
                maxWidth: maxWidth,
                scaleX: scaleX,
                scaleY: scaleY
            )
        case .checklist:
            ChecklistBlockView(content: block.content, styling: block.styling, onButtonTap: onButtonTap, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .video:
            VideoBlockView(content: block.content, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .slider:
            SliderBlockView(content: block.content, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .progress:
            ProgressBlockView(content: block.content, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .loadingIndicator:
            LoadingIndicatorBlockView(content: block.content, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
        case .featureCard:
            FeatureCardBlockView(content: block.content, maxWidth: maxWidth, scaleX: scaleX, scaleY: scaleY)
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
    var collectedData: [String: String] = [:]  // For variable interpolation
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    // Interpolate variables in the text
    private var displayText: String {
        interpolateText(content.text ?? "", with: collectedData)
    }

    // Computed properties for font configuration
    // Sizes match Tailwind CSS: h1=text-3xl(30), h2=text-2xl(24), h3=text-xl(20), body=text-base(16), caption=text-sm(14), label=text-xs(12)
    private var fontSize: CGFloat {
        // Use explicit fontSize if provided, otherwise use variant-based size
        let baseSize: CGFloat
        if let size = content.fontSize {
            baseSize = CGFloat(size)
        } else {
            switch content.variant {
            case "h1": baseSize = 30  // text-3xl
            case "h2": baseSize = 24  // text-2xl
            case "h3": baseSize = 20  // text-xl
            case "caption": baseSize = 14  // text-sm
            case "label": baseSize = 12  // text-xs
            default: baseSize = 16 // body = text-base
            }
        }
        // Use scaleX for font sizing (width-based scaling)
        return baseSize * scaleX
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

    // Get font using fontFamily if specified, with iOS fallback mapping
    private var font: Font {
        makeFont(family: content.fontFamily, size: fontSize, weight: fontWeight)
    }

    private var textColor: Color {
        // Use color or textColor property
        if let colorHex = content.color ?? content.textColor {
            return Color(hex: colorHex)
        }
        // Fall back to first richText span's color if available
        if let spans = content.richText, let firstSpan = spans.first, let spanColor = firstSpan.color {
            return Color(hex: spanColor)
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

    // Build Text view from richText spans with per-span formatting
    private func buildRichText() -> Text {
        guard let spans = content.richText, !spans.isEmpty else {
            return Text(displayText)
        }

        var result = Text("")
        for span in spans {
            // Interpolate variables in span text
            let interpolatedText = interpolateText(span.text, with: collectedData)
            var spanText = Text(interpolatedText)

            // Apply span-specific font family if specified
            if let spanFontFamily = span.fontFamily {
                let spanFontSize = span.fontSize.map { CGFloat($0) } ?? fontSize
                spanText = spanText.font(makeFont(family: spanFontFamily, size: spanFontSize, weight: fontWeight))
            }

            // Apply span-specific color or fall back to first span's color
            if let spanColor = span.color {
                spanText = spanText.foregroundColor(Color(hex: spanColor))
            } else if let firstSpan = spans.first, let firstColor = firstSpan.color {
                spanText = spanText.foregroundColor(Color(hex: firstColor))
            }

            // Apply bold/italic
            if span.bold == true && span.italic == true {
                spanText = spanText.bold().italic()
            } else if span.bold == true {
                spanText = spanText.bold()
            } else if span.italic == true {
                spanText = spanText.italic()
            }

            // Apply underline
            if span.underline == true {
                spanText = spanText.underline()
            }

            result = result + spanText
        }
        return result
    }

    var body: some View {
        let hasRichText = content.richText != nil && !content.richText!.isEmpty
        let _ = print("🔍 [TextBlockView] text='\(content.text ?? "nil")' displayText='\(displayText)' variant='\(content.variant ?? "nil")' fontFamily='\(content.fontFamily ?? "system")' color='\(content.color ?? "nil")' richText=\(hasRichText ? "\(content.richText!.count) spans" : "nil") fontSize=\(fontSize)")

        Group {
            if let spans = content.richText, !spans.isEmpty {
                // Render rich text with per-span formatting
                buildRichText()
                    .font(font)
            } else {
                // Render plain text with variable interpolation
                Text(displayText)
                    .font(font)
                    .foregroundColor(textColor)
            }
        }
        .multilineTextAlignment(textAlignment)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: maxWidth ?? .infinity, alignment: frameAlignment)
    }
}

struct IconBlockView: View {
    let content: BlockContent
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    var body: some View {
        Text(content.icon ?? "")
            .font(.system(size: sizeForDimension(content.size) * scaleX))
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
    var styling: BlockStyling? = nil  // For borderRadius from styling
    var collectedData: [String: String] = [:]  // For variable interpolation
    let onTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    // Use styling.borderRadius first, fall back to content.borderRadius
    // Use scaleX for border radius (width-based scaling)
    private var effectiveBorderRadius: CGFloat {
        CGFloat(styling?.borderRadius ?? content.borderRadius ?? 12) * scaleX
    }

    // Interpolate variables in button text
    private var displayText: String {
        interpolateText(content.text ?? "Continue", with: collectedData)
    }

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
        let base: CGFloat
        if let explicit = content.paddingHorizontal { base = CGFloat(explicit) }
        else {
            switch buttonSize {
            case "sm": base = 16
            case "lg": base = 32
            default: base = 24 // md
            }
        }
        return base * scaleX  // Horizontal padding uses scaleX
    }

    private var verticalPadding: CGFloat {
        let base: CGFloat
        if let explicit = content.paddingVertical { base = CGFloat(explicit) }
        else {
            switch buttonSize {
            case "sm": base = 8
            case "lg": base = 16
            default: base = 12 // md
            }
        }
        return base * scaleY  // Vertical padding uses scaleY
    }

    private var fontSize: CGFloat {
        let base: CGFloat
        if let explicit = content.fontSize { base = CGFloat(explicit) }
        else {
            switch buttonSize {
            case "sm": base = 14
            case "lg": base = 18
            default: base = 16 // md
            }
        }
        return base * scaleX  // Font size uses scaleX
    }

    private var iconSize: CGFloat {
        let base: CGFloat
        switch buttonSize {
        case "sm": base = 16
        case "lg": base = 24
        default: base = 20 // md
        }
        return base * scaleX  // Icon size uses scaleX
    }

    // Helper to convert gradient angle to SwiftUI start/end points
    private func gradientPoints(for angle: Int) -> (start: UnitPoint, end: UnitPoint) {
        // Angle is in degrees, where 0 = bottom to top, 90 = left to right
        // Convert CSS gradient angle to SwiftUI unit points
        let normalizedAngle = angle % 360
        switch normalizedAngle {
        case 0: return (.bottom, .top)
        case 45: return (.bottomLeading, .topTrailing)
        case 90: return (.leading, .trailing)
        case 135: return (.topLeading, .bottomTrailing)
        case 180: return (.top, .bottom)
        case 225: return (.topTrailing, .bottomLeading)
        case 270: return (.trailing, .leading)
        case 315: return (.bottomTrailing, .topLeading)
        default: return (.top, .bottom) // Default vertical
        }
    }

    // Background view - supports gradients or solid colors
    @ViewBuilder
    private var buttonBackground: some View {
        if let gradient = content.backgroundGradient {
            let colors = gradient.colors.map { Color(hex: $0) }
            if gradient.type == .radial {
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            } else {
                let points = gradientPoints(for: gradient.angle ?? 180)
                LinearGradient(
                    colors: colors,
                    startPoint: points.start,
                    endPoint: points.end
                )
            }
        } else {
            Color(hex: content.backgroundColor ?? "#10b981")
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

                    Text(displayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: content.textColor ?? "#ffffff"))
                        .frame(maxWidth: .infinity)

                    // Spacer to balance the icon
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20 * scaleX)
                .padding(.vertical, 16 * scaleY)
                .frame(maxWidth: content.fullWidth == true ? .infinity : nil)
                .background(buttonBackground)
                .cornerRadius(effectiveBorderRadius)
            } else if isGhostVariant {
                // Ghost/link button - no background, just text
                HStack(spacing: 8) {
                    if let icon = content.icon, content.iconPosition != "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }

                    Text(displayText)
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

                    Text(displayText)
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
                    RoundedRectangle(cornerRadius: effectiveBorderRadius)
                        .stroke(Color(hex: content.backgroundColor ?? "#ffffff"), lineWidth: 2 * scaleX)
                )
            } else {
                // Primary/default button - filled background
                HStack(spacing: 8 * scaleX) {
                    if let icon = content.icon, content.iconPosition != "right" {
                        Text(icon)
                            .font(.system(size: iconSize))
                    }

                    Text(displayText)
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
                .background(buttonBackground)
                .cornerRadius(effectiveBorderRadius)
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
    var scaleY: CGFloat = 1.0

    var body: some View {
        let spacerHeight: CGFloat = {
            switch content.height {
            case .number(let value):
                return CGFloat(value) * scaleY
            case .string(let str):
                return CGFloat(Int(str) ?? 16) * scaleY
            case .none:
                return 16 * scaleY
            }
        }()
        Spacer().frame(height: spacerHeight)
    }
}

struct ImageBlockView: View {
    let content: BlockContent
    var styling: BlockStyling? = nil
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    // Use styling.borderRadius first, fall back to content.borderRadius
    private var effectiveBorderRadius: CGFloat {
        CGFloat(styling?.borderRadius ?? content.borderRadius ?? 0) * scaleX
    }

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
            .cornerRadius(effectiveBorderRadius)
        }
    }
}

struct DividerBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    var scaleY: CGFloat = 1.0

    var body: some View {
        Rectangle()
            .fill(Color(hex: content.color ?? "#333333"))
            .frame(height: CGFloat(content.thickness ?? 1) * scaleY)
            .frame(maxWidth: maxWidth ?? .infinity)
    }
}

struct InputBlockView: View {
    let content: BlockContent
    var styling: BlockStyling?
    @Binding var collectedData: [String: String]  // For variable binding
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    // Get the field name for this input (used to store/retrieve value)
    private var fieldName: String {
        (content.fieldName ?? content.fieldLabel ?? "").trimmingCharacters(in: .whitespaces)
    }

    // Use styling if available, otherwise fall back to content properties
    private var backgroundColor: Color {
        if let bg = styling?.backgroundColor ?? content.backgroundColor {
            return Color(hex: bg)
        }
        return Color(hex: "#1e293b")
    }

    private var borderRadius: CGFloat {
        CGFloat(styling?.borderRadius ?? content.borderRadius ?? 12) * scaleX
    }

    private var borderColor: Color {
        if let bc = styling?.borderColor {
            return Color(hex: bc)
        }
        return Color.white.opacity(0.2)
    }

    private var borderWidth: CGFloat {
        CGFloat(styling?.borderWidth ?? 1) * scaleX
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
        let _ = print("🔍 [InputBlockView] fieldName='\(fieldName)' placeholder='\(content.placeholder ?? "nil")' value='\(collectedData[fieldName] ?? "")' bgColor='\(styling?.backgroundColor ?? content.backgroundColor ?? "default")' borderRadius=\(borderRadius)")

        VStack(alignment: .leading, spacing: 8) {
            // Label
            if let label = content.label ?? content.fieldLabel {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
            }

            // Text field with proper placeholder
            // Using binding to collectedData for the field value
            TextField(
                "",
                text: Binding(
                    get: { collectedData[fieldName] ?? "" },
                    set: { newValue in
                        if !fieldName.isEmpty {
                            collectedData[fieldName] = newValue
                        }
                    }
                ),
                prompt: Text(content.placeholder ?? "Enter text...")
                    .foregroundColor(placeholderColor)
            )
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
    var styling: BlockStyling? = nil
    let onButtonTap: (ButtonAction) -> Void
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    @State private var selectedItems: Set<String> = []

    private var activeColor: Color {
        Color(hex: content.activeColor ?? "#10b981")
    }

    private var inactiveColor: Color {
        if let color = content.inactiveColor {
            return Color(hex: color)
        }
        return Color.white.opacity(0.1)
    }

    private var textColor: Color {
        if let color = content.textColor ?? content.color {
            return Color(hex: color)
        }
        return .white
    }

    private var itemBackgroundColor: Color {
        if let bg = content.backgroundColor {
            return Color(hex: bg)
        }
        return Color.white.opacity(0.05)
    }

    private var hasShadow: Bool {
        // Check if shadow is enabled (could be bool or string "true")
        if let items = content.items, !items.isEmpty {
            // Shadow is typically a boolean, but handle as optional
            return false // Default to no shadow, enable via content.shadow if added to model
        }
        return false
    }

    private var checklistStyle: String {
        content.checklistStyle ?? content.style ?? "list"
    }

    private var columns: Int {
        content.columns ?? 1
    }

    // Styling options with defaults - apply non-uniform scaling
    private var fontSize: CGFloat {
        CGFloat(content.fontSize ?? 14) * scaleX
    }

    private var itemPadding: CGFloat {
        CGFloat(content.itemPadding ?? 12) * scaleX  // Use scaleX for padding
    }

    private var itemGap: CGFloat {
        CGFloat(content.itemGap ?? 8) * scaleY  // Use scaleY for vertical gap
    }

    private var borderRadius: CGFloat {
        CGFloat(styling?.borderRadius ?? content.itemBorderRadius ?? content.borderRadius ?? 12) * scaleX
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
                        inactiveColor: inactiveColor,
                        textColor: textColor,
                        backgroundColor: itemBackgroundColor,
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
                                inactiveColor: inactiveColor,
                                textColor: textColor,
                                backgroundColor: itemBackgroundColor,
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
                    inactiveColor: inactiveColor,
                    textColor: textColor,
                    backgroundColor: itemBackgroundColor,
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
                                inactiveColor: inactiveColor,
                                textColor: textColor,
                                backgroundColor: itemBackgroundColor,
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
                                inactiveColor: inactiveColor,
                                textColor: textColor,
                                backgroundColor: itemBackgroundColor,
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
    var inactiveColor: Color = Color.white.opacity(0.1)
    var textColor: Color = .white
    var backgroundColor: Color = Color.white.opacity(0.05)
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
                        .stroke(isSelected ? activeColor : inactiveColor, lineWidth: 2)
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
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? activeColor.opacity(0.12) : backgroundColor)
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
    var inactiveColor: Color = Color.white.opacity(0.1)
    var textColor: Color = .white
    var backgroundColor: Color = Color.white.opacity(0.1)
    var fontSize: CGFloat = 14
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 9999
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(item.label)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(isSelected ? .white : textColor.opacity(0.8))
                .padding(.horizontal, padding * 1.5)
                .padding(.vertical, padding * 0.7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius == 9999 ? 9999 : cornerRadius)
                        .fill(isSelected ? activeColor : backgroundColor)
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
    var inactiveColor: Color = Color.white.opacity(0.1)
    var textColor: Color = .white
    var backgroundColor: Color = Color.white.opacity(0.1)
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
                        inactiveColor: inactiveColor,
                        textColor: textColor,
                        backgroundColor: backgroundColor,
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
    var inactiveColor: Color = Color.white.opacity(0.1)
    var textColor: Color = .white
    var backgroundColor: Color = Color.white.opacity(0.05)
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
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Circular indicator in top-right
                ZStack {
                    Circle()
                        .stroke(isSelected ? activeColor : inactiveColor, lineWidth: 2)
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
                    .fill(isSelected ? activeColor.opacity(0.1) : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? activeColor : inactiveColor, lineWidth: 2)
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
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

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
                    .frame(width: 60 * scaleX, height: 60 * scaleX)

                Image(systemName: "play.fill")
                    .font(.system(size: 24 * scaleX))
                    .foregroundColor(Color(hex: "#0f172a"))
                    .offset(x: 2 * scaleX)
            }
            .frame(maxWidth: maxWidth ?? .infinity)
            .frame(height: 200 * scaleY)
            .cornerRadius(CGFloat(content.borderRadius ?? 12) * scaleX)
            .clipped()
        }
    }
}

struct ProgressBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    var body: some View {
        // Simple progress bar placeholder
        // The actual progress would be controlled by the parent view
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4 * scaleX)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8 * scaleY)

                RoundedRectangle(cornerRadius: 4 * scaleX)
                    .fill(Color(hex: content.color ?? "#10b981"))
                    .frame(width: geometry.size.width * 0.5, height: 8 * scaleY)
            }
        }
        .frame(height: 8 * scaleY)
        .frame(maxWidth: maxWidth ?? .infinity)
    }
}

// MARK: - Slider Block

struct SliderBlockView: View {
    let content: BlockContent
    var maxWidth: CGFloat?
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    private var minValue: Int { content.min ?? 0 }
    private var maxValue: Int { content.max ?? 100 }
    private var currentValue: Int { content.defaultValue ?? ((minValue + maxValue) / 2) }

    private var fillColor: Color { Color(hex: content.fillColor ?? "#f97316") }
    private var trackColor: Color { Color(hex: content.trackColor ?? "rgba(200, 200, 200, 0.3)") }
    private var thumbColor: Color { Color(hex: content.thumbColor ?? "#ffffff") }

    private var thumbSizeValue: CGFloat { CGFloat(content.thumbSize ?? 32) * scaleX }
    private var trackHeightValue: CGFloat { CGFloat(content.trackHeight ?? 12) * scaleY }

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
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    @State private var progress: CGFloat = 0.34 // Static preview

    private var fillColor: Color { Color(hex: content.fillColor ?? "#f97316") }
    private var trackColor: Color { Color(hex: content.trackColor ?? "#e5e5e5") }
    private var size: CGFloat { CGFloat(content.thumbSize ?? 120) * scaleX } // Reusing thumbSize for circle size
    private var strokeWidth: CGFloat { CGFloat(content.trackHeight ?? 8) * scaleX }

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
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scaleY) {
            // Headline (using text property)
            if let headline = content.text {
                Text(headline)
                    .font(.system(size: 24 * scaleX, weight: .bold))
                    .foregroundColor(Color(hex: content.color ?? "#000000"))
            }
        }
        .padding(.horizontal, 24 * scaleX)
        .padding(.vertical, 24 * scaleY)
        .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
        .background(Color(hex: content.backgroundColor ?? "#ffffff"))
        .cornerRadius(CGFloat(content.borderRadius ?? 16) * scaleX)
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

