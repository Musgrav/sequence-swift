// ============================================
// Layout Converter
// ============================================
// Converts old block-based layouts (with x/y positions)
// to the new declarative layout tree format.
// This enables backward compatibility with existing flows.
// ============================================

import Foundation

public struct LayoutConverter {
    
    /// Converts old screen content with blocks to a ScreenLayout
    /// - Parameters:
    ///   - content: The screen content containing blocks
    ///   - screenId: The screen identifier
    ///   - extraTopPadding: Additional top padding (e.g., for progress indicator at top)
    public static func convert(from content: ScreenContent, screenId: String, extraTopPadding: CGFloat = 0) -> ScreenLayout {
        // If already using new format, return as-is (future)
        // For now, convert blocks to layout tree
        
        let blocks = content.blocks ?? []
        
        // Sort blocks by Y position (top to bottom), then by order
        let sortedBlocks = blocks.sorted { block1, block2 in
            let y1 = block1.position?.y ?? CGFloat(block1.order * 60)
            let y2 = block2.position?.y ?? CGFloat(block2.order * 60)
            if y1 == y2 {
                return block1.order < block2.order
            }
            return y1 < y2
        }
        
        // Convert blocks to layout nodes
        var children: [LayoutNode] = []
        var lastY: CGFloat = 0
        
        // Add top spacing (base 24pt from safe area + extra for progress indicator if at top)
        let topSpacing: CGFloat = 24 + extraTopPadding
        children.append(LayoutNode(
            id: "\(screenId)_spacer_top",
            type: .spacer,
            content: ContentProperties(spacerSize: topSpacing)
        ))
        
        for (index, block) in sortedBlocks.enumerated() {
            // Calculate spacing from previous block
            let currentY = block.position?.y ?? CGFloat(index * 60 + 150)
            
            if index > 0 {
                let gap = max(0, currentY - lastY - 50) // Approximate previous block height
                if gap > 8 {
                    children.append(LayoutNode(
                        id: "\(screenId)_spacer_\(index)",
                        type: .spacer,
                        content: ContentProperties(spacerSize: gap)
                    ))
                }
            }
            
            // Convert block to layout node
            if let node = convertBlock(block, screenId: screenId) {
                children.append(node)
            }
            
            lastY = currentY
        }

        // Check if there are any flexible spacers - if so, don't use ScrollView
        // because Spacer() doesn't work inside ScrollView
        let hasFlexibleSpacer = children.contains { node in
            node.type == .spacer && node.content?.spacerFlex != nil && node.content?.spacerFlex ?? 0 > 0
        }

        // Create root layout
        let vstack = LayoutNode(
            id: "\(screenId)_vstack",
            type: .vstack,
            children: children,
            layout: LayoutProperties(
                alignment: .center,
                spacing: 0,
                padding: .symmetric(vertical: nil, horizontal: 24),
                height: .fill
            )
        )

        // If we have flexible spacers, use VStack directly without ScrollView
        // This allows Spacer() to expand and push content to edges
        let rootNode: LayoutNode
        if hasFlexibleSpacer {
            rootNode = vstack
        } else {
            rootNode = LayoutNode(
                id: "\(screenId)_scroll",
                type: .scroll,
                children: [vstack],
                layout: LayoutProperties(
                    scrollDirection: .vertical,
                    showsScrollIndicator: false
                )
            )
        }

        return ScreenLayout(
            version: 1,
            root: rootNode,
            backgroundColor: content.backgroundColor,
            backgroundGradient: convertGradient(content.backgroundGradient),
            safeAreaMode: .respect
        )
    }
    
    /// Converts a single block to a layout node
    private static func convertBlock(_ block: ContentBlock, screenId: String) -> LayoutNode? {
        let nodeId = block.id
        
        switch block.type {
        case .text:
            return LayoutNode(
                id: nodeId,
                type: .text,
                content: ContentProperties(
                    text: block.content.text,
                    textVariant: convertTextVariant(block.content.variant),
                    textAlign: convertTextAlign(block.content.align),
                    textColor: block.content.color.map { .fixed($0) },
                    fontWeight: convertFontWeight(block.content.fontWeight),
                    fontSize: block.content.fontSizeValue,
                    fontFamily: block.content.fontFamily,
                    lineHeight: block.content.lineHeight,
                    letterSpacing: block.content.letterSpacing
                )
            )
            
        case .icon:
            return LayoutNode(
                id: nodeId,
                type: .icon,
                content: ContentProperties(
                    icon: block.content.icon,
                    iconSize: convertIconSize(block.content.size),
                    iconColor: block.content.color
                )
            )
            
        case .button:
            return LayoutNode(
                id: nodeId,
                type: .button,
                style: StyleProperties(
                    backgroundColor: block.content.backgroundColor,
                    borderRadius: block.content.borderRadius != nil ? .all(CGFloat(block.content.borderRadius!)) : nil
                ),
                content: ContentProperties(
                    buttonText: block.content.text,
                    buttonVariant: convertButtonVariant(block.content.variant),
                    buttonAction: convertButtonAction(block.content.action),
                    buttonIcon: block.content.icon,
                    buttonIconPosition: block.content.iconPosition == "right" ? .trailing : .leading,
                    buttonTextColor: block.content.textColor.map { .fixed($0) },
                    fullWidth: block.content.fullWidth
                )
            )
            
        case .spacer:
            // Check if this is a flexible spacer
            if block.content.flex == true {
                return LayoutNode(
                    id: nodeId,
                    type: .spacer,
                    content: ContentProperties(spacerFlex: 1, spacerMinSize: 0)
                )
            }
            // Fixed height spacer
            let height: CGFloat
            switch block.content.height {
            case .number(let h): height = CGFloat(h)
            case .string(let s): height = CGFloat(Int(s) ?? 24)
            case .none: height = 24
            }
            return LayoutNode(
                id: nodeId,
                type: .spacer,
                content: ContentProperties(spacerSize: height)
            )
            
        case .image:
            return LayoutNode(
                id: nodeId,
                type: .image,
                style: StyleProperties(
                    borderRadius: block.content.borderRadius != nil ? .all(CGFloat(block.content.borderRadius!)) : nil
                ),
                content: ContentProperties(
                    src: block.content.src,
                    alt: block.content.alt,
                    contentMode: .fit
                )
            )
            
        case .checklist:
            return LayoutNode(
                id: nodeId,
                type: .checklist,
                content: ContentProperties(
                    checklistItems: convertChecklistItems(block.content.items),
                    allowMultiple: block.content.allowMultiple,
                    minSelections: block.content.minSelections,
                    maxSelections: block.content.maxSelections,
                    checklistStyle: convertChecklistStyle(block.content.checklistStyle ?? block.content.style),
                    checklistAction: convertButtonAction(block.content.action),
                    autoAdvance: block.content.autoAdvance,
                    activeColor: block.content.activeColor,
                    checklistFontSize: block.content.fontSize != nil ? CGFloat(block.content.fontSize!) : nil,
                    checklistItemPadding: block.content.itemPadding != nil ? CGFloat(block.content.itemPadding!) : nil,
                    checklistItemGap: block.content.itemGap != nil ? CGFloat(block.content.itemGap!) : nil,
                    checklistBorderRadius: block.content.itemBorderRadius != nil ? CGFloat(block.content.itemBorderRadius!) : (block.content.borderRadius != nil ? CGFloat(block.content.borderRadius!) : nil),
                    checklistColumns: block.content.columns
                )
            )
            
        case .progress:
            return LayoutNode(
                id: nodeId,
                type: .progress,
                content: ContentProperties(
                    progressVariant: .bar,
                    fillColor: block.content.color,
                    trackColor: "rgba(255,255,255,0.2)"
                )
            )
            
        case .divider:
            return LayoutNode(
                id: nodeId,
                type: .divider,
                content: ContentProperties(
                    dividerColor: block.content.color,
                    dividerThickness: block.content.thickness != nil ? CGFloat(block.content.thickness!) : 1
                )
            )
            
        case .input:
            return LayoutNode(
                id: nodeId,
                type: .input,
                content: ContentProperties(
                    inputPlaceholder: block.content.placeholder,
                    inputLabel: block.content.label,
                    inputFieldName: block.content.fieldName,
                    required: block.content.required
                )
            )
            
        case .video:
            return LayoutNode(
                id: nodeId,
                type: .video,
                content: ContentProperties(
                    videoSrc: block.content.src,
                    videoPoster: block.content.poster,
                    autoplay: block.content.autoplay,
                    loop: block.content.loop
                )
            )
            
        case .lottie:
            return LayoutNode(
                id: nodeId,
                type: .lottie,
                content: ContentProperties(
                    lottieSrc: block.content.src
                )
            )
            
        case .custom, .unknown:
            return LayoutNode(
                id: nodeId,
                type: .custom,
                content: ContentProperties(
                    customIdentifier: block.content.identifier
                )
            )
        }
    }
    
    // MARK: - Conversion Helpers
    
    private static func convertTextVariant(_ variant: String?) -> TextVariant? {
        switch variant {
        case "h1": return .h1
        case "h2": return .h2
        case "h3": return .h3
        case "body": return .body
        case "caption": return .caption
        case "label": return .label
        default: return .body
        }
    }
    
    private static func convertTextAlign(_ align: String?) -> TextAlign? {
        switch align {
        case "left": return .leading
        case "right": return .trailing
        case "center": return .center
        default: return .center
        }
    }
    
    private static func convertFontWeight(_ weight: String?) -> FontWeight? {
        switch weight {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        default: return .regular
        }
    }
    
    private static func convertIconSize(_ size: String?) -> IconSize? {
        guard let size = size else { return .preset("lg") }
        return .preset(size)
    }
    
    private static func convertButtonVariant(_ variant: String?) -> ButtonVariant? {
        switch variant {
        case "primary": return .primary
        case "secondary": return .secondary
        case "outline": return .outline
        case "ghost": return .ghost
        default: return .primary
        }
    }
    
    private static func convertButtonAction(_ action: ButtonAction?) -> LayoutButtonAction? {
        guard let action = action else { return .next }
        
        switch action {
        case .next: return .next
        case .previous: return .previous
        case .screen(let screenId): return .screen(screenId: screenId)
        case .complete: return .complete
        case .custom(let identifier): return .custom(identifier: identifier)
        }
    }
    
    private static func convertChecklistItems(_ items: [ChecklistItem]?) -> [ChecklistItemData]? {
        items?.map { item in
            ChecklistItemData(
                id: item.id,
                label: item.label,
                icon: nil,
                description: nil
            )
        }
    }
    
    private static func convertChecklistStyle(_ style: String?) -> ChecklistStyle? {
        switch style {
        case "list": return .list
        case "pills": return .pills
        case "cards": return .cards
        default: return .pills  // Default to 'pills' to match editor
        }
    }
    
    private static func convertGradient(_ gradient: BackgroundGradient?) -> GradientStyle? {
        guard let gradient = gradient else { return nil }
        return GradientStyle(
            type: gradient.type == .linear ? .linear : .radial,
            colors: gradient.colors,
            angle: gradient.angle != nil ? CGFloat(gradient.angle!) : nil
        )
    }
}

// MARK: - Integration with existing OnboardingViewModel

extension OnboardingViewModel {
    /// Converts the current screen to a ScreenLayout using the converter
    /// - Parameters:
    ///   - screen: The screen to convert
    ///   - extraTopPadding: Additional top padding for progress indicator
    func getDeclarativeLayout(for screen: Screen, extraTopPadding: CGFloat = 0) -> ScreenLayout {
        return LayoutConverter.convert(from: screen.content, screenId: screen.id, extraTopPadding: extraTopPadding)
    }
}

