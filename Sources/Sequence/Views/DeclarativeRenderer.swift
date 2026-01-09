// ============================================
// Declarative Layout Renderer
// ============================================
// Maps the declarative layout tree to native SwiftUI views.
// This ensures consistent rendering across all iOS devices.
// ============================================

import SwiftUI
import UIKit

// MARK: - Design Constants
// These MUST match web/src/lib/device-constants.ts
// Based on iPhone 15/16 Pro dimensions (393 × 852 points)
private let designCanvasWidth: CGFloat = 393
private let designCanvasHeight: CGFloat = 852

// MARK: - Scale Factor Environment Key
// Used to pass the scale factor through the view hierarchy for font scaling

private struct ScaleFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var layoutScaleFactor: CGFloat {
        get { self[ScaleFactorKey.self] }
        set { self[ScaleFactorKey.self] = newValue }
    }
}

// MARK: - Layout Node Renderer

/// Recursively renders a LayoutNode tree to SwiftUI views
public struct LayoutNodeView: View {
    let node: LayoutNode
    let onButtonTap: (LayoutButtonAction) -> Void
    
    public init(node: LayoutNode, onButtonTap: @escaping (LayoutButtonAction) -> Void) {
        self.node = node
        self.onButtonTap = onButtonTap
    }
    
    public var body: some View {
        // Skip invisible nodes
        if node.visible == false {
            EmptyView()
        } else {
            nodeContent
                .modifier(LayoutModifier(layout: node.layout))
                .modifier(StyleModifier(style: node.style))
        }
    }
    
    @ViewBuilder
    private var nodeContent: some View {
        switch node.type {
        // Containers
        case .scroll:
            ScrollNodeView(node: node, onButtonTap: onButtonTap)
        case .vstack:
            VStackNodeView(node: node, onButtonTap: onButtonTap)
        case .hstack:
            HStackNodeView(node: node, onButtonTap: onButtonTap)
        case .zstack:
            ZStackNodeView(node: node, onButtonTap: onButtonTap)
        case .spacer:
            SpacerNodeView(content: node.content)
        case .safeArea:
            SafeAreaNodeView(node: node, onButtonTap: onButtonTap)
        // Content
        case .text:
            TextNodeView(content: node.content)
        case .icon:
            IconNodeView(content: node.content)
        case .image:
            ImageNodeView(content: node.content, style: node.style)
        case .button:
            ButtonNodeView(content: node.content, style: node.style, onTap: onButtonTap)
        case .input:
            InputNodeView(content: node.content, style: node.style)
        case .checklist:
            ChecklistNodeView(content: node.content, style: node.style, onTap: onButtonTap)
        case .progress:
            ProgressNodeView(content: node.content)
        case .divider:
            DividerNodeView(content: node.content)
        case .video:
            VideoNodeView(content: node.content, style: node.style)
        case .lottie:
            LottieNodeView(content: node.content)
        case .custom:
            CustomNodeView(content: node.content)
        // New components for template DSL
        case .slider:
            SliderNodeView(content: node.content, style: node.style)
        case .picker:
            PickerNodeView(content: node.content, style: node.style)
        case .review:
            ReviewNodeView(content: node.content, style: node.style)
        case .sticker:
            StickerNodeView(content: node.content, style: node.style)
        case .loading:
            LoadingNodeView(content: node.content, style: node.style)
        case .featureCard:
            FeatureCardNodeView(content: node.content, style: node.style)
        }
    }
}

// MARK: - Container Views

struct ScrollNodeView: View {
    let node: LayoutNode
    let onButtonTap: (LayoutButtonAction) -> Void
    
    var body: some View {
        let direction = node.layout?.scrollDirection ?? .vertical
        let showsIndicator = node.layout?.showsScrollIndicator ?? true
        
        if direction == .horizontal {
            ScrollView(.horizontal, showsIndicators: showsIndicator) {
                HStack(spacing: 0) {
                    ForEach(node.children ?? []) { child in
                        LayoutNodeView(node: child, onButtonTap: onButtonTap)
                    }
                }
            }
        } else {
            ScrollView(.vertical, showsIndicators: showsIndicator) {
                VStack(spacing: 0) {
                    ForEach(node.children ?? []) { child in
                        LayoutNodeView(node: child, onButtonTap: onButtonTap)
                    }
                }
            }
        }
    }
}

struct VStackNodeView: View {
    let node: LayoutNode
    let onButtonTap: (LayoutButtonAction) -> Void
    
    var body: some View {
        let alignment = mapAlignment(node.layout?.alignment)
        let spacing = node.layout?.spacing ?? 0
        let childCount = node.children?.count ?? 0
        
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(node.children ?? []) { child in
                LayoutNodeView(node: child, onButtonTap: onButtonTap)
            }
        }
        .onAppear {
            print("🎨 [VStackNodeView] Rendering VStack with \(childCount) children, spacing=\(spacing)")
        }
    }
    
    private func mapAlignment(_ alignment: LayoutAlignment?) -> HorizontalAlignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, .fill, .none: return .center
        }
    }
}

struct HStackNodeView: View {
    let node: LayoutNode
    let onButtonTap: (LayoutButtonAction) -> Void
    
    var body: some View {
        let alignment = mapAlignment(node.layout?.alignment)
        let spacing = node.layout?.spacing ?? 0
        
        HStack(alignment: alignment, spacing: spacing) {
            ForEach(node.children ?? []) { child in
                LayoutNodeView(node: child, onButtonTap: onButtonTap)
            }
        }
    }
    
    private func mapAlignment(_ alignment: LayoutAlignment?) -> VerticalAlignment {
        switch alignment {
        case .leading: return .top
        case .trailing: return .bottom
        case .center, .fill, .none: return .center
        }
    }
}

struct ZStackNodeView: View {
    let node: LayoutNode
    let onButtonTap: (LayoutButtonAction) -> Void
    
    var body: some View {
        let alignment = mapAlignment(node.layout?.alignment)
        
        ZStack(alignment: alignment) {
            ForEach(node.children ?? []) { child in
                LayoutNodeView(node: child, onButtonTap: onButtonTap)
            }
        }
    }
    
    private func mapAlignment(_ alignment: LayoutAlignment?) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, .fill, .none: return .center
        }
    }
}

struct SafeAreaNodeView: View {
    let node: LayoutNode
    let onButtonTap: (LayoutButtonAction) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(node.children ?? []) { child in
                LayoutNodeView(node: child, onButtonTap: onButtonTap)
            }
        }
    }
}

struct SpacerNodeView: View {
    let content: ContentProperties?
    
    // Get scale factor from environment for proportional sizing
    @Environment(\.layoutScaleFactor) private var scaleFactor
    
    var body: some View {
        if let fixedSize = content?.spacerSize {
            Spacer().frame(height: fixedSize * scaleFactor)
        } else if let flex = content?.spacerFlex, flex > 0 {
            let minSize = (content?.spacerMinSize ?? 0) * scaleFactor
            Spacer(minLength: minSize)
        } else {
            Spacer()
        }
    }
}

// MARK: - Content Views

struct TextNodeView: View {
    let content: ContentProperties?

    // State to trigger refresh when font loads
    @State private var fontRefreshTrigger = UUID()

    // Get scale factor from environment for proportional font sizing
    @Environment(\.layoutScaleFactor) private var scaleFactor
    // Get color scheme for adaptive colors
    @Environment(\.colorScheme) private var colorScheme

    /// Resolve text color - handles adaptive colors
    private var resolvedTextColor: Color {
        if let colorValue = content?.textColor {
            return Color(hex: colorValue.resolve(for: colorScheme))
        }
        // Default to white for dark backgrounds, black for light
        return colorScheme == .dark ? Color(hex: "#ffffff") : Color(hex: "#000000")
    }

    var body: some View {
        textView
            .foregroundColor(resolvedTextColor)
            .multilineTextAlignment(alignmentForValue(content?.textAlign))
            .lineLimit(content?.lineLimit)
            .lineSpacing(lineSpacingForContent())
            .fixedSize(horizontal: false, vertical: true)
            .id(fontRefreshTrigger) // Force refresh when font loads
            .onAppear {
                loadFontIfNeeded()
            }
    }
    
    @ViewBuilder
    private var textView: some View {
        // Build the text with font (weight is included in fontForContent)
        let text = Text(content?.text ?? "")
            .font(fontForContent())
        
        if #available(iOS 16.0, *) {
            text.tracking(content?.letterSpacing ?? 0)
        } else {
            // Letter spacing not supported on iOS < 16, render text without it
            text
        }
    }
    
    /// Request font loading if needed, refresh view when ready
    private func loadFontIfNeeded() {
        guard let fontFamily = content?.fontFamily, !fontFamily.isEmpty else { return }
        
        // Check if font is already available
        if FontManager.shared.isFontAvailable(fontFamily) {
            return
        }
        
        // Request the font to load
        FontManager.shared.loadFont(fontFamily) { success in
            if success {
                // Trigger view refresh by changing the id
                fontRefreshTrigger = UUID()
            }
        }
    }
    
    /// Creates the appropriate font based on content properties
    /// Note: Weight is included in the font to avoid iOS 16+ fontWeight modifier
    /// Font size is scaled proportionally to the device
    private func fontForContent() -> Font {
        let baseSize = fontSizeForVariant(content?.textVariant)
        // Scale the font size proportionally to the device
        let size = baseSize * scaleFactor
        let weight = weightForValue(content?.fontWeight)
        
        // Debug logging
        print("🎨 [TextNodeView] Creating font - size: \(size), weight: \(weight), fontFamily: \(content?.fontFamily ?? "nil")")
        
        // If a custom font family is specified, try to use it
        if let fontFamily = content?.fontFamily, !fontFamily.isEmpty {
            // Check if it should use system font
            if isSystemFont(fontFamily) {
                print("🎨 [TextNodeView] Using system font for '\(fontFamily)'")
                return .system(size: size, weight: weight)
            }
            
            // Try to get the font from FontManager (handles dynamic loading)
            let uiWeight = weight.toUIFontWeight()
            if let customFont = FontManager.shared.getFont(named: fontFamily, size: size, weight: uiWeight) {
                print("🎨 [TextNodeView] Using font '\(fontFamily)'")
                return Font(customFont)
            }
            
            // Font not available yet - trigger async download
            if !FontManager.shared.isFontAvailable(fontFamily) {
                print("🔤 [TextNodeView] Font '\(fontFamily)' not available, requesting download...")
                FontManager.shared.loadFont(fontFamily) { success in
                    if success {
                        print("✅ [TextNodeView] Font '\(fontFamily)' is now available")
                        // Note: View will need to refresh to pick up the new font
                        // This happens automatically on next render
                    }
                }
            }
            
            // While font is loading, try iOS fallback
            let fallbackName = mapToiOSFont(fontFamily)
            if fallbackName != fontFamily {
                print("🔄 [TextNodeView] Using fallback '\(fallbackName)' while '\(fontFamily)' loads")
                if let fallbackFont = UIFont(name: fallbackName, size: size) {
                    return Font(fallbackFont)
                }
                let weightSuffix = fontWeightSuffix(weight)
                if let fallbackFont = UIFont(name: "\(fallbackName)-\(weightSuffix)", size: size) {
                    return Font(fallbackFont)
                }
            }
        }
        
        // Use system font with the appropriate size and weight
        return .system(size: size, weight: weight)
    }
    
    /// Checks if the font family should use system font
    private func isSystemFont(_ fontFamily: String) -> Bool {
        let lowercased = fontFamily.lowercased()
        let systemFonts = [
            "inter", "sf pro", "sf pro display", "sf pro text",
            "-apple-system", "system-ui", "system", "default"
        ]
        return systemFonts.contains(lowercased)
    }
    
    /// Tries to find a font with the given name and weight
    private func findFont(named fontFamily: String, size: CGFloat, weight: Font.Weight) -> UIFont? {
        let weightSuffix = fontWeightSuffix(weight)
        
        // Try exact font name first
        if let font = UIFont(name: fontFamily, size: size) {
            return font
        }
        
        // Try with weight suffix (e.g., "WorkSans-Bold")
        let fontNameWithWeight = "\(fontFamily)-\(weightSuffix)"
        if let font = UIFont(name: fontNameWithWeight, size: size) {
            return font
        }
        
        // Try removing spaces (e.g., "Work Sans" -> "WorkSans")
        let noSpaces = fontFamily.replacingOccurrences(of: " ", with: "")
        if noSpaces != fontFamily {
            if let font = UIFont(name: noSpaces, size: size) {
                return font
            }
            if let font = UIFont(name: "\(noSpaces)-\(weightSuffix)", size: size) {
                return font
            }
        }
        
        // Try common iOS equivalents (maps web fonts to iOS font names)
        let mappedName = mapToiOSFont(fontFamily)
        if mappedName != fontFamily {
            if let font = UIFont(name: mappedName, size: size) {
                return font
            }
            let mappedWithWeight = "\(mappedName)-\(weightSuffix)"
            if let font = UIFont(name: mappedWithWeight, size: size) {
                return font
            }
        }
        
        // Print helpful message about bundling custom fonts
        print("⚠️ [TextNodeView] To use '\(fontFamily)', add the font files to your Xcode project:")
        print("⚠️ [TextNodeView]   1. Add .ttf or .otf files to your app target")
        print("⚠️ [TextNodeView]   2. Add font names to Info.plist under 'Fonts provided by application'")
        print("⚠️ [TextNodeView]   3. Use the exact PostScript name (check Font Book on Mac)")
        
        return nil
    }
    
    /// Returns the font name suffix for a given weight
    private func fontWeightSuffix(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold: return "Bold"
        case .semibold: return "SemiBold"
        case .medium: return "Medium"
        case .regular: return "Regular"
        case .light: return "Light"
        default: return "Regular"
        }
    }
    
    /// Maps web font names to iOS system fonts or common equivalents
    /// For custom fonts like Google Fonts, they must be bundled with the app
    private func mapToiOSFont(_ fontFamily: String) -> String {
        let lowercased = fontFamily.lowercased()
        
        switch lowercased {
        // Monospace fonts
        case "sf mono", "menlo", "monaco", "consolas", "fira code", "jetbrains mono":
            return "Menlo"
        case "courier", "courier new":
            return "Courier"
            
        // Serif fonts
        case "georgia":
            return "Georgia"
        case "times", "times new roman", "noto serif", "merriweather", "playfair display":
            return "TimesNewRomanPSMT"
        case "palatino", "book antiqua":
            return "Palatino"
            
        // Sans-serif fonts - map common Google Fonts to similar iOS fonts
        case "helvetica", "helvetica neue":
            return "HelveticaNeue"
        case "arial", "roboto", "open sans", "lato", "source sans pro":
            return "HelveticaNeue" // Close visual match
        case "avenir", "nunito", "poppins", "montserrat":
            return "Avenir"
        case "avenir next", "raleway", "quicksand":
            return "AvenirNext"
        case "work sans", "dm sans", "ibm plex sans":
            return "AvenirNext" // Good geometric sans fallback
        case "space grotesk", "space mono":
            return "Menlo"
        case "oswald", "bebas neue":
            return "HelveticaNeue" // Condensed alternative would be better
            
        // Rounded fonts
        case "nunito sans", "varela round", "comfortaa":
            return "AvenirNext"
            
        default:
            return fontFamily
        }
    }
    
    /// Gets the font size, preferring custom size over variant-based size
    private func fontSizeForVariant(_ variant: TextVariant?) -> CGFloat {
        // Custom size takes precedence
        if let customSize = content?.fontSize {
            return customSize
        }
        
        // Fall back to variant-based sizes
        switch variant {
        case .h1: return 34
        case .h2: return 28
        case .h3: return 22
        case .caption: return 12
        case .label: return 14
        case .body, .none: return 16
        }
    }
    
    /// Calculates line spacing from line height
    private func lineSpacingForContent() -> CGFloat {
        guard let lineHeight = content?.lineHeight else { return 0 }
        let fontSize = fontSizeForVariant(content?.textVariant)
        // lineHeight is a multiplier (e.g., 1.5), convert to extra spacing
        // SwiftUI lineSpacing is extra space between lines, not the total line height
        let totalLineHeight = fontSize * lineHeight
        return max(0, totalLineHeight - fontSize)
    }
    
    private func weightForValue(_ weight: FontWeight?) -> Font.Weight {
        switch weight {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .regular, .none: return .regular
        }
    }
    
    private func alignmentForValue(_ align: TextAlign?) -> SwiftUI.TextAlignment {
        switch align {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, .none: return .center
        }
    }
}

struct IconNodeView: View {
    let content: ContentProperties?
    
    // Get scale factor from environment for proportional sizing
    @Environment(\.layoutScaleFactor) private var scaleFactor
    
    var body: some View {
        let baseSize = content?.iconSize?.cgFloat ?? 48
        let size = baseSize * scaleFactor
        let color = Color(hex: content?.iconColor ?? "#ffffff")
        
        // Check if it's an SF Symbol or emoji
        if let icon = content?.icon {
            if icon.hasPrefix("sf:") {
                // SF Symbol
                let symbolName = String(icon.dropFirst(3))
                Image(systemName: symbolName)
                    .font(.system(size: size))
                    .foregroundColor(color)
            } else {
                // Emoji
                Text(icon)
                    .font(.system(size: size))
            }
        }
    }
}

struct ImageNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    
    var body: some View {
        if let src = content?.src, let url = URL(string: src) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: mapContentMode(content?.contentMode))
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(style?.borderRadius?.cornerRadius ?? 0)
        }
    }
    
    private func mapContentMode(_ mode: ContentMode?) -> SwiftUI.ContentMode {
        switch mode {
        case .fill: return .fill
        case .fit, .center, .none: return .fit
        }
    }
}

struct ButtonNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    let onTap: (LayoutButtonAction) -> Void

    // Get scale factor from environment for proportional sizing
    @Environment(\.layoutScaleFactor) private var scaleFactor
    // Get color scheme for adaptive colors
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            if let action = content?.buttonAction {
                onTap(action)
            }
        }) {
            HStack(spacing: 8 * scaleFactor) {
                // Leading icon
                if let icon = content?.buttonIcon,
                   content?.buttonIconPosition != .trailing {
                    Text(icon).font(.system(size: 20 * scaleFactor))
                }

                Text(content?.buttonText ?? "Continue")
                    .font(.system(size: 17 * scaleFactor, weight: .semibold))

                // Trailing icon
                if let icon = content?.buttonIcon,
                   content?.buttonIconPosition == .trailing {
                    Text(icon).font(.system(size: 20 * scaleFactor))
                }
            }
            .frame(maxWidth: content?.fullWidth == true ? .infinity : nil)
            .padding(.horizontal, 24 * scaleFactor)
            .padding(.vertical, 16 * scaleFactor)
            .foregroundColor(buttonTextColor)
            .background(backgroundForVariant(content?.buttonVariant, customColor: style?.backgroundColor))
            .cornerRadius((style?.borderRadius?.cornerRadius ?? 12) * scaleFactor)
            .overlay(overlayForVariant(content?.buttonVariant, radius: (style?.borderRadius?.cornerRadius ?? 12) * scaleFactor))
        }
    }

    // Use custom button text color if provided (supports adaptive), otherwise fall back to variant default
    private var buttonTextColor: Color {
        if let colorValue = content?.buttonTextColor {
            return Color(hex: colorValue.resolve(for: colorScheme))
        }
        return textColorForVariant(content?.buttonVariant)
    }

    private func textColorForVariant(_ variant: ButtonVariant?) -> Color {
        switch variant {
        case .ghost, .outline:
            return Color(hex: "#ffffff")
        case .secondary:
            return Color(hex: "#ffffff")
        case .primary, .none:
            return Color(hex: "#ffffff")
        }
    }
    
    private func backgroundForVariant(_ variant: ButtonVariant?, customColor: String?) -> Color {
        if let custom = customColor {
            return Color(hex: custom)
        }
        switch variant {
        case .secondary:
            return Color.white.opacity(0.1)
        case .ghost:
            return Color.clear
        case .outline:
            return Color.clear
        case .primary, .none:
            return Color(hex: "#10b981")
        }
    }
    
    @ViewBuilder
    private func overlayForVariant(_ variant: ButtonVariant?, radius: CGFloat) -> some View {
        if variant == .outline {
            RoundedRectangle(cornerRadius: radius)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        } else {
            EmptyView()
        }
    }
}

struct InputNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @State private var text: String = ""
    
    // Get scale factor from environment for proportional sizing
    @Environment(\.layoutScaleFactor) private var scaleFactor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if let label = content?.inputLabel {
                Text(label)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            TextField(content?.inputPlaceholder ?? "", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16 * scaleFactor))
                .foregroundColor(.white)
                .padding(.horizontal, 16 * scaleFactor)
                .padding(.vertical, 14 * scaleFactor)
                .background(Color(hex: style?.backgroundColor ?? "#1e293b"))
                .cornerRadius((style?.borderRadius?.cornerRadius ?? 15) * scaleFactor)
                .overlay(
                    RoundedRectangle(cornerRadius: (style?.borderRadius?.cornerRadius ?? 15) * scaleFactor)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChecklistNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    let onTap: (LayoutButtonAction) -> Void
    @State private var selectedItems: Set<String> = []
    
    // Get scale factor from environment for proportional sizing
    @Environment(\.layoutScaleFactor) private var scaleFactor
    
    private var items: [ChecklistItemData] {
        content?.checklistItems ?? []
    }
    
    private var checklistStyle: ChecklistStyle {
        content?.checklistStyle ?? .pills  // Default to 'pills' to match editor
    }
    
    private var activeColor: Color {
        Color(hex: content?.activeColor ?? "#10b981")
    }
    
    // Styling properties with defaults - scaled by scaleFactor
    private var fontSize: CGFloat {
        (content?.checklistFontSize ?? 14) * scaleFactor
    }
    
    private var itemPadding: CGFloat {
        (content?.checklistItemPadding ?? 12) * scaleFactor
    }
    
    private var itemGap: CGFloat {
        (content?.checklistItemGap ?? 8) * scaleFactor
    }
    
    private var borderRadius: CGFloat {
        (content?.checklistBorderRadius ?? 12) * scaleFactor
    }
    
    private var columns: Int {
        content?.checklistColumns ?? 1
    }
    
    var body: some View {
        Group {
            switch checklistStyle {
            case .pills:
                pillsLayout
            case .cards:
                cardsLayout
            case .list:
                listLayout
            }
        }
    }
    
    // MARK: - List Style
    
    private var listLayout: some View {
        VStack(spacing: itemGap) {
            ForEach(items) { item in
                ChecklistItemView(
                    item: item,
                    isSelected: selectedItems.contains(item.id),
                    style: checklistStyle,
                    activeColor: activeColor,
                    fontSize: fontSize,
                    padding: itemPadding,
                    cornerRadius: borderRadius,
                    onToggle: { toggleItem(item) }
                )
            }
        }
    }
    
    // MARK: - Pills Style
    
    private var pillsLayout: some View {
        Group {
            if columns == 2 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: itemGap) {
                    ForEach(items) { item in
                        ChecklistPillItemView(
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
            } else {
                VStack(spacing: itemGap) {
                    ForEach(items) { item in
                        ChecklistPillItemView(
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
    
    // MARK: - Cards Style
    
    private var cardsLayout: some View {
        Group {
            if columns == 2 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: itemGap) {
                    ForEach(items) { item in
                        ChecklistItemView(
                            item: item,
                            isSelected: selectedItems.contains(item.id),
                            style: .cards,
                            activeColor: activeColor,
                            fontSize: fontSize,
                            padding: itemPadding,
                            cornerRadius: borderRadius,
                            onToggle: { toggleItem(item) }
                        )
                    }
                }
            } else {
                VStack(spacing: itemGap) {
                    ForEach(items) { item in
                        ChecklistItemView(
                            item: item,
                            isSelected: selectedItems.contains(item.id),
                            style: .cards,
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
    
    private func toggleItem(_ item: ChecklistItemData) {
        if content?.allowMultiple == true {
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                if let max = content?.maxSelections, selectedItems.count >= max {
                    return
                }
                selectedItems.insert(item.id)
            }
        } else {
            selectedItems = [item.id]
            
            // Auto-advance on single select
            if content?.autoAdvance ?? true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let action = content?.checklistAction {
                        onTap(action)
                    }
                }
            }
        }
    }
}

// MARK: - Checklist Item View (List & Cards style)

struct ChecklistItemView: View {
    let item: ChecklistItemData
    let isSelected: Bool
    let style: ChecklistStyle
    let activeColor: Color
    var fontSize: CGFloat = 14
    var padding: CGFloat = 12
    var cornerRadius: CGFloat = 12
    let onToggle: () -> Void
    
    private var indicatorSize: CGFloat {
        max(16, fontSize + 4)
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator (circle with checkmark)
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
                
                // Label
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
                    .stroke(isSelected ? activeColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected && style == .cards ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Checklist Pill Item View (Pills style)

struct ChecklistPillItemView: View {
    let item: ChecklistItemData
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

struct ProgressNodeView: View {
    let content: ContentProperties?
    
    private var fillColor: Color {
        Color(hex: content?.fillColor ?? "#10b981")
    }
    
    private var trackColor: Color {
        Color(hex: content?.trackColor ?? "rgba(255,255,255,0.2)")
    }
    
    var body: some View {
        switch content?.progressVariant ?? .bar {
        case .bar:
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(trackColor)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * (content?.progressValue ?? 0.5))
                }
            }
            .frame(height: 8)
            
        case .dots:
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? fillColor : trackColor)
                        .frame(width: index == 0 ? 16 : 8, height: 8)
                }
            }
            
        case .steps:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(index == 0 ? fillColor : trackColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(index == 0 ? fillColor : trackColor)
                        )
                    
                    if index < 2 {
                        Rectangle()
                            .fill(trackColor)
                            .frame(width: 20, height: 2)
                    }
                }
            }
            
        case .ring:
            Circle()
                .stroke(trackColor, lineWidth: 4)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .trim(from: 0, to: content?.progressValue ?? 0.5)
                        .stroke(fillColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                )
        }
    }
}

struct DividerNodeView: View {
    let content: ContentProperties?
    
    var body: some View {
        Rectangle()
            .fill(Color(hex: content?.dividerColor ?? "#333333"))
            .frame(height: content?.dividerThickness ?? 1)
    }
}

struct VideoNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    
    var body: some View {
        // Video player placeholder
        ZStack {
            if let poster = content?.videoPoster, let url = URL(string: poster) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(hex: "#1e293b"))
                }
            } else {
                Rectangle().fill(Color(hex: "#1e293b"))
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
        .frame(height: 200)
        .cornerRadius(style?.borderRadius?.cornerRadius ?? 12)
        .clipped()
    }
}

struct LottieNodeView: View {
    let content: ContentProperties?
    
    var body: some View {
        // Lottie placeholder - real implementation would use lottie-ios
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 200, height: 200)
            .overlay(
                Text("Lottie")
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

struct CustomNodeView: View {
    let content: ContentProperties?

    var body: some View {
        // Custom component placeholder
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 100)
            .overlay(
                Text(content?.customIdentifier ?? "Custom Component")
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

// MARK: - Slider Node View

struct SliderNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @State private var value: Double = 0
    @Environment(\.layoutScaleFactor) private var scaleFactor

    private var minValue: Double {
        Double(content?.sliderMin ?? 0)
    }

    private var maxValue: Double {
        Double(content?.sliderMax ?? 100)
    }

    private var step: Double {
        Double(content?.sliderStep ?? 1)
    }

    private var fillColor: Color {
        Color(hex: content?.fillColor ?? "#10b981")
    }

    private var trackColor: Color {
        Color(hex: content?.trackColor ?? "rgba(255,255,255,0.2)")
    }

    private var thumbColor: Color {
        Color(hex: content?.sliderThumbColor ?? "#ffffff")
    }

    var body: some View {
        VStack(spacing: 16 * scaleFactor) {
            // Value display
            if content?.sliderShowValue ?? true {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if let prefix = content?.sliderValuePrefix {
                        Text(prefix)
                            .font(.system(size: (content?.sliderValueFontSize ?? 48) * scaleFactor, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("\(Int(value))")
                        .font(.system(size: (content?.sliderValueFontSize ?? 48) * scaleFactor, weight: .bold))
                        .foregroundColor(.white)
                    if let suffix = content?.sliderValueSuffix {
                        Text(suffix)
                            .font(.system(size: (content?.sliderSuffixFontSize ?? 20) * scaleFactor, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            // Custom slider track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4 * scaleFactor)
                        .fill(trackColor)
                        .frame(height: 8 * scaleFactor)

                    // Fill
                    let progress = (value - minValue) / (maxValue - minValue)
                    RoundedRectangle(cornerRadius: 4 * scaleFactor)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * progress, height: 8 * scaleFactor)

                    // Thumb
                    Circle()
                        .fill(thumbColor)
                        .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .offset(x: (geometry.size.width - 28 * scaleFactor) * progress)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    let newProgress = min(max(gesture.location.x / geometry.size.width, 0), 1)
                                    let newValue = minValue + (maxValue - minValue) * newProgress
                                    // Snap to step
                                    value = (newValue / step).rounded() * step
                                    value = min(max(value, minValue), maxValue)
                                }
                        )
                }
                .frame(height: 28 * scaleFactor)
            }
            .frame(height: 28 * scaleFactor)

            // Min/Max labels
            if content?.sliderShowMinMax ?? true {
                HStack {
                    Text("\(Int(minValue))")
                        .font(.system(size: 14 * scaleFactor))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(Int(maxValue))")
                        .font(.system(size: 14 * scaleFactor))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .onAppear {
            value = Double(content?.sliderDefaultValue ?? content?.sliderMin ?? 0)
        }
    }
}

// MARK: - Picker Node View

struct PickerNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @State private var selectedValue: Int = 0
    @Environment(\.layoutScaleFactor) private var scaleFactor
    @Environment(\.colorScheme) private var colorScheme

    private var pickerHeight: CGFloat {
        (content?.pickerHeight ?? 200) * scaleFactor
    }

    private var highlightColor: Color {
        Color(hex: content?.pickerHighlightColor ?? "rgba(255,255,255,0.1)")
    }

    private var textColor: Color {
        if let colorValue = content?.textColor {
            return Color(hex: colorValue.resolve(for: colorScheme))
        }
        return Color(hex: "rgba(255,255,255,0.6)")
    }

    private var selectedTextColor: Color {
        Color(hex: content?.pickerSelectedTextColor ?? "#ffffff")
    }

    var body: some View {
        // Generate options based on preset
        let options = generateOptions()

        ZStack {
            // Selection highlight
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(highlightColor)
                .frame(height: 40 * scaleFactor)

            // Picker
            Picker("", selection: $selectedValue) {
                ForEach(0..<options.count, id: \.self) { index in
                    Text(options[index])
                        .foregroundColor(index == selectedValue ? selectedTextColor : textColor)
                        .tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: pickerHeight)
        }
    }

    private func generateOptions() -> [String] {
        switch content?.pickerPreset {
        case .age:
            return (18...100).map { "\($0)" }
        case .weight:
            return (30...200).map { "\($0) kg" }
        case .height:
            return (100...220).map { "\($0) cm" }
        case .date, .dateOfBirth:
            // Simplified - in production, use DatePicker
            return (1950...2010).map { "\($0)" }
        case .time:
            var times: [String] = []
            for hour in 0..<24 {
                for minute in stride(from: 0, to: 60, by: 15) {
                    times.append(String(format: "%02d:%02d", hour, minute))
                }
            }
            return times
        case .custom, .none:
            // Use custom columns if provided
            if let columns = content?.pickerColumns, let firstColumn = columns.first {
                if let items = firstColumn.items {
                    return items.map { $0.label }
                } else if let min = firstColumn.min, let max = firstColumn.max {
                    let step = firstColumn.step ?? 1
                    let prefix = firstColumn.prefix ?? ""
                    let suffix = firstColumn.suffix ?? ""
                    return stride(from: min, through: max, by: step).map { "\(prefix)\($0)\(suffix)" }
                }
            }
            return ["Option 1", "Option 2", "Option 3"]
        }
    }
}

// MARK: - Review Node View

struct ReviewNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    @Environment(\.layoutScaleFactor) private var scaleFactor

    private var maxRating: Int {
        content?.reviewMaxRating ?? 5
    }

    private var emojis: [String] {
        content?.reviewEmojis ?? ["😢", "😕", "😐", "🙂", "😊"]
    }

    private var starColor: Color {
        Color(hex: content?.reviewStarColor ?? "#f59e0b")
    }

    private var starEmptyColor: Color {
        Color(hex: content?.reviewStarEmptyColor ?? "rgba(255,255,255,0.2)")
    }

    private var size: CGFloat {
        (content?.reviewSize?.cgFloat ?? 32) * scaleFactor
    }

    var body: some View {
        VStack(spacing: 16 * scaleFactor) {
            // Rating selector
            HStack(spacing: 8 * scaleFactor) {
                if content?.reviewType == .emoji {
                    // Emoji rating
                    ForEach(0..<emojis.count, id: \.self) { index in
                        Text(emojis[index])
                            .font(.system(size: size))
                            .opacity(rating == index + 1 ? 1.0 : 0.4)
                            .scaleEffect(rating == index + 1 ? 1.2 : 1.0)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    rating = index + 1
                                }
                            }
                    }
                } else {
                    // Star rating
                    ForEach(1...maxRating, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: size))
                            .foregroundColor(star <= rating ? starColor : starEmptyColor)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    rating = star
                                }
                            }
                    }
                }
            }

            // Optional text input
            if content?.reviewShowTextInput ?? false {
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if reviewText.isEmpty {
                        Text(content?.reviewTextPlaceholder ?? "Tell us more...")
                            .font(.system(size: 16 * scaleFactor))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(16 * scaleFactor)
                    }

                    // TextEditor for multiline (iOS 15 compatible)
                    TextEditor(text: $reviewText)
                        .font(.system(size: 16 * scaleFactor))
                        .foregroundColor(.white)
                        .padding(12 * scaleFactor)
                        .frame(minHeight: 100 * scaleFactor)
                        .onAppear {
                            // Make TextEditor background transparent on iOS 15
                            UITextView.appearance().backgroundColor = .clear
                        }
                }
                .background(Color.white.opacity(0.1))
                .cornerRadius(12 * scaleFactor)
            }
        }
        .onAppear {
            rating = content?.reviewDefaultRating ?? 0
        }
    }
}

// MARK: - Sticker Node View

struct StickerNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @Environment(\.layoutScaleFactor) private var scaleFactor
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        Color(hex: style?.backgroundColor ?? "#ef4444")
    }

    private var textColor: Color {
        if let colorValue = content?.textColor {
            return Color(hex: colorValue.resolve(for: colorScheme))
        }
        return Color(hex: "#ffffff")
    }

    private var stickerSize: StickerSize {
        content?.stickerSize ?? .md
    }

    private var rotation: Double {
        Double(content?.stickerRotation ?? 0)
    }

    var body: some View {
        let fontSize = stickerSize.fontSize * scaleFactor
        let padding = stickerSize.padding * scaleFactor

        Group {
            switch content?.stickerVariant ?? .badge {
            case .badge:
                Text(content?.stickerText ?? "NEW")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(textColor)
                    .padding(.horizontal, padding * 1.5)
                    .padding(.vertical, padding * 0.5)
                    .background(backgroundColor)
                    .cornerRadius(4 * scaleFactor)

            case .ribbon:
                Text(content?.stickerText ?? "SALE")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(textColor)
                    .padding(.horizontal, padding * 2)
                    .padding(.vertical, padding * 0.5)
                    .background(
                        ZStack {
                            backgroundColor
                            // Ribbon notch effect
                            HStack {
                                Spacer()
                                Triangle()
                                    .fill(backgroundColor.opacity(0.7))
                                    .frame(width: 10 * scaleFactor, height: padding)
                                    .rotationEffect(.degrees(180))
                            }
                        }
                    )

            case .circle:
                Text(content?.stickerText ?? "50%")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(textColor)
                    .frame(width: padding * 4, height: padding * 4)
                    .background(backgroundColor)
                    .clipShape(Circle())

            case .burst:
                ZStack {
                    // Burst shape
                    StarBurst(points: 12)
                        .fill(backgroundColor)
                        .frame(width: padding * 5, height: padding * 5)

                    Text(content?.stickerText ?? "WOW")
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(textColor)
                }
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// Helper shapes for sticker
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StarBurst: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.6

        for i in 0..<points * 2 {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Loading Node View

struct LoadingNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @State private var progress: Double = 0
    @State private var currentMessageIndex: Int = 0
    @State private var isAnimating: Bool = false
    @Environment(\.layoutScaleFactor) private var scaleFactor

    private var duration: Double {
        Double(content?.loadingDuration ?? 3000) / 1000.0
    }

    private var size: CGFloat {
        (content?.loadingSize ?? 120) * scaleFactor
    }

    private var strokeWidth: CGFloat {
        (content?.loadingStrokeWidth ?? 8) * scaleFactor
    }

    private var fillColor: Color {
        Color(hex: content?.fillColor ?? "#10b981")
    }

    private var trackColor: Color {
        Color(hex: content?.trackColor ?? "rgba(255,255,255,0.1)")
    }

    private var messages: [LoadingMessage] {
        content?.loadingMessages ?? []
    }

    private var currentMessage: String {
        guard !messages.isEmpty else { return "" }

        // Find the appropriate message based on progress
        let percentage = Int(progress * 100)
        var messageToShow = messages[0].text

        for message in messages {
            if let atPercent = message.atPercent, percentage >= atPercent {
                messageToShow = message.text
            }
        }

        return messageToShow
    }

    var body: some View {
        VStack(spacing: 24 * scaleFactor) {
            // Loading indicator
            switch content?.loadingVariant ?? .circular {
            case .circular:
                circularIndicator
            case .bar:
                barIndicator
            case .dots:
                dotsIndicator
            }

            // Message
            if !messages.isEmpty {
                Text(currentMessage)
                    .font(.system(size: (content?.loadingMessageFontSize ?? 16) * scaleFactor))
                    .foregroundColor(Color(hex: content?.loadingMessageColor ?? "#ffffff"))
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: currentMessage)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private var circularIndicator: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    gradientFill,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Percentage
            if content?.loadingShowPercentage ?? true {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: (content?.loadingPercentageFontSize ?? 32) * scaleFactor, weight: .bold))
                    .foregroundColor(Color(hex: content?.loadingPercentageColor ?? "#ffffff"))
            }
        }
    }

    private var barIndicator: some View {
        VStack(spacing: 8 * scaleFactor) {
            if content?.loadingShowPercentage ?? true {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: (content?.loadingPercentageFontSize ?? 24) * scaleFactor, weight: .bold))
                    .foregroundColor(Color(hex: content?.loadingPercentageColor ?? "#ffffff"))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: strokeWidth / 2)
                        .fill(trackColor)

                    RoundedRectangle(cornerRadius: strokeWidth / 2)
                        .fill(gradientFill)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: strokeWidth)
        }
    }

    private var dotsIndicator: some View {
        HStack(spacing: 8 * scaleFactor) {
            ForEach(0..<6, id: \.self) { index in
                let dotProgress = progress * 6
                let isActive = Double(index) < dotProgress

                Circle()
                    .fill(isActive ? fillColor : trackColor)
                    .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
            }
        }
    }

    private var gradientFill: some ShapeStyle {
        if let colors = content?.loadingGradientColors, colors.count >= 2 {
            return AnyShapeStyle(
                AngularGradient(
                    colors: colors.map { Color(hex: $0) },
                    center: .center
                )
            )
        }
        return AnyShapeStyle(fillColor)
    }

    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(.easeOut(duration: duration)) {
            progress = 1.0
        }
    }
}

// MARK: - Feature Card Node View

struct FeatureCardNodeView: View {
    let content: ContentProperties?
    let style: StyleProperties?
    @Environment(\.layoutScaleFactor) private var scaleFactor

    private var headlineColor: Color {
        Color(hex: content?.featureHeadlineColor ?? "#ffffff")
    }

    private var bodyColor: Color {
        Color(hex: content?.featureBodyColor ?? "rgba(255,255,255,0.8)")
    }

    private var backgroundColor: Color {
        Color(hex: style?.backgroundColor ?? "rgba(255,255,255,0.05)")
    }

    private var glowColor: Color {
        Color(hex: content?.featureGlowColor ?? style?.borderColor ?? "#10b981")
    }

    private var borderRadius: CGFloat {
        (style?.borderRadius?.cornerRadius ?? 16) * scaleFactor
    }

    private var padding: CGFloat {
        (content?.checklistItemPadding ?? 20) * scaleFactor
    }

    private var textAlign: SwiftUI.TextAlignment {
        switch content?.featureAlign {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, .none: return .center
        }
    }

    private var frameAlign: Alignment {
        switch content?.featureAlign {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, .none: return .center
        }
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: (content?.featureHeadlineBodyGap ?? 8) * scaleFactor) {
            // Headline
            if let headline = content?.featureHeadline {
                Text(headline)
                    .font(.system(
                        size: (content?.featureHeadlineFontSize ?? 18) * scaleFactor,
                        weight: mapFontWeight(content?.featureHeadlineFontWeight)
                    ))
                    .foregroundColor(headlineColor)
                    .multilineTextAlignment(textAlign)
            }

            // Body
            if let body = content?.featureBody {
                Text(body)
                    .font(.system(
                        size: (content?.featureBodyFontSize ?? 14) * scaleFactor,
                        weight: mapFontWeight(content?.featureBodyFontWeight)
                    ))
                    .foregroundColor(bodyColor)
                    .multilineTextAlignment(textAlign)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlign)
        .padding(padding)
        .background(backgroundColor)
        .cornerRadius(borderRadius)
        .overlay(
            RoundedRectangle(cornerRadius: borderRadius)
                .stroke(
                    style?.borderColor != nil ? Color(hex: style!.borderColor!) : Color.clear,
                    lineWidth: (style?.borderWidth ?? 0) * scaleFactor
                )
        )
        .modifier(GlowModifier(
            enabled: content?.featureGlowingBorder ?? false,
            color: glowColor,
            intensity: content?.featureGlowIntensity ?? 0.5,
            radius: borderRadius
        ))
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch content?.featureAlign {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, .none: return .center
        }
    }

    private func mapFontWeight(_ weight: FontWeight?) -> Font.Weight {
        switch weight {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .regular, .none: return .regular
        }
    }
}

// Glow effect modifier
struct GlowModifier: ViewModifier {
    let enabled: Bool
    let color: Color
    let intensity: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: color.opacity(Double(intensity)), radius: 8, x: 0, y: 0)
                .shadow(color: color.opacity(Double(intensity) * 0.5), radius: 16, x: 0, y: 0)
        } else {
            content
        }
    }
}

// MARK: - Modifiers

struct LayoutModifier: ViewModifier {
    let layout: LayoutProperties?
    
    func body(content: Content) -> some View {
        content
            .padding(layout?.padding?.edgeInsets ?? EdgeInsets())
            .frame(
                minWidth: layout?.minWidth,
                maxWidth: mapMaxWidth(layout?.maxWidth, fill: layout?.width),
                minHeight: layout?.minHeight,
                maxHeight: mapMaxHeight(layout?.maxHeight, fill: layout?.height)
            )
    }
    
    private func mapMaxWidth(_ maxWidth: CGFloat?, fill: SizeValue?) -> CGFloat? {
        if case .fill = fill {
            return .infinity
        }
        return maxWidth
    }
    
    private func mapMaxHeight(_ maxHeight: CGFloat?, fill: SizeValue?) -> CGFloat? {
        if case .fill = fill {
            return .infinity
        }
        return maxHeight
    }
}

struct StyleModifier: ViewModifier {
    let style: StyleProperties?
    
    func body(content: Content) -> some View {
        content
            .background(backgroundView)
            .cornerRadius(style?.borderRadius?.cornerRadius ?? 0)
            .opacity(style?.opacity ?? 1)
            .shadow(
                color: Color(hex: style?.shadow?.color ?? "#000000").opacity(0.3),
                radius: style?.shadow?.radius ?? 0,
                x: style?.shadow?.x ?? 0,
                y: style?.shadow?.y ?? 0
            )
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if let gradient = style?.backgroundGradient {
            let colors = gradient.colors.compactMap { Color(hex: $0) }
            if gradient.type == .linear {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            } else {
                RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 200)
            }
        } else if let bgColor = style?.backgroundColor {
            Color(hex: bgColor)
        } else {
            Color.clear
        }
    }
}

// MARK: - Screen Layout View

/// Main view for rendering a screen layout
public struct ScreenLayoutView: View {
    let layout: ScreenLayout
    let onButtonTap: (LayoutButtonAction) -> Void
    
    public init(layout: ScreenLayout, onButtonTap: @escaping (LayoutButtonAction) -> Void) {
        self.layout = layout
        self.onButtonTap = onButtonTap
    }
    
    public var body: some View {
        GeometryReader { geometry in
            // Calculate scale factor based on device WIDTH relative to design canvas
            // Using width-based scale keeps proportions for elements while filling screen
            let scaleFactor = geometry.size.width / designCanvasWidth
            
            // Content with scale factor injected into environment
            // Background is handled by parent ScreenView
            LayoutNodeView(node: layout.root, onButtonTap: onButtonTap)
                .environment(\.layoutScaleFactor, scaleFactor)
                .modifier(SafeAreaModifier(mode: layout.safeAreaMode))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    print("🎨 [ScreenLayoutView] Rendering layout with scale factor: \(scaleFactor)")
                    print("🎨 [ScreenLayoutView]   - Device size: \(geometry.size.width) x \(geometry.size.height)")
                    print("🎨 [ScreenLayoutView]   - Design canvas: \(designCanvasWidth) x \(designCanvasHeight)")
                    print("🎨 [ScreenLayoutView]   - Root type: \(layout.root.type)")
                }
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if let gradient = layout.backgroundGradient {
            let colors = gradient.colors.compactMap { Color(hex: $0) }
            if gradient.type == .linear {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            } else {
                RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 400)
            }
        } else {
            Color(hex: layout.backgroundColor ?? "#0f172a")
        }
    }
}

struct SafeAreaModifier: ViewModifier {
    let mode: ScreenLayout.SafeAreaMode?
    
    func body(content: Content) -> some View {
        switch mode {
        case .ignore:
            content.ignoresSafeArea()
        case .ignoreTop:
            content.ignoresSafeArea(edges: .top)
        case .ignoreBottom:
            content.ignoresSafeArea(edges: .bottom)
        case .respect, .none:
            content
        }
    }
}

