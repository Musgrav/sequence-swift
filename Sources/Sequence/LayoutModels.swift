// ============================================
// Declarative Layout Models
// ============================================
// These models map directly to SwiftUI primitives for
// reliable cross-device rendering. NO absolute positioning.
// ============================================

import Foundation
import SwiftUI

// MARK: - Layout Node Types

public enum LayoutNodeType: String, Codable, Sendable {
    // Containers
    case scroll
    case vstack
    case hstack
    case zstack
    case spacer
    case safeArea = "safe-area"
    // Content
    case text
    case icon
    case image
    case button
    case input
    case checklist
    case progress
    case divider
    case video
    case lottie
    case custom
    // New components for template DSL
    case slider
    case picker
    case review
    case sticker
    case loading
    case featureCard = "feature-card"
}

// MARK: - Layout Node

public struct LayoutNode: Codable, Identifiable, Sendable {
    public let id: String
    public let type: LayoutNodeType
    public var children: [LayoutNode]?
    public var layout: LayoutProperties?
    public var style: StyleProperties?
    public var content: ContentProperties?
    public var visible: Bool?
    public var animation: AnimationProperties?
    public var accessibility: AccessibilityProperties?
    
    public init(
        id: String,
        type: LayoutNodeType,
        children: [LayoutNode]? = nil,
        layout: LayoutProperties? = nil,
        style: StyleProperties? = nil,
        content: ContentProperties? = nil,
        visible: Bool? = nil,
        animation: AnimationProperties? = nil,
        accessibility: AccessibilityProperties? = nil
    ) {
        self.id = id
        self.type = type
        self.children = children
        self.layout = layout
        self.style = style
        self.content = content
        self.visible = visible
        self.animation = animation
        self.accessibility = accessibility
    }
}

// MARK: - Layout Properties

public struct LayoutProperties: Codable, Sendable {
    // Alignment
    public var alignment: LayoutAlignment?
    public var justifyContent: JustifyContent?
    
    // Spacing
    public var spacing: CGFloat?
    public var padding: PaddingValue?
    public var margin: PaddingValue?
    
    // Size constraints
    public var width: SizeValue?
    public var height: SizeValue?
    public var minWidth: CGFloat?
    public var maxWidth: CGFloat?
    public var minHeight: CGFloat?
    public var maxHeight: CGFloat?
    
    // Flex behavior
    public var flex: CGFloat?
    
    // Scroll behavior
    public var scrollDirection: ScrollDirection?
    public var showsScrollIndicator: Bool?
    
    // Safe area
    public var safeAreaEdges: [SafeAreaEdge]?
}

public enum LayoutAlignment: String, Codable, Sendable {
    case leading
    case center
    case trailing
    case fill
}

public enum JustifyContent: String, Codable, Sendable {
    case start
    case center
    case end
    case spaceBetween
    case spaceAround
}

public enum ScrollDirection: String, Codable, Sendable {
    case vertical
    case horizontal
}

public enum SafeAreaEdge: String, Codable, Sendable {
    case top
    case bottom
    case leading
    case trailing
}

// MARK: - Size Value

public enum SizeValue: Codable, Sendable {
    case fixed(CGFloat)
    case auto
    case fill
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(CGFloat.self) {
            self = .fixed(number)
        } else if let string = try? container.decode(String.self) {
            switch string {
            case "auto": self = .auto
            case "fill": self = .fill
            default: self = .auto
            }
        } else {
            self = .auto
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .fixed(let value): try container.encode(value)
        case .auto: try container.encode("auto")
        case .fill: try container.encode("fill")
        }
    }
}

// MARK: - Padding Value

public enum PaddingValue: Codable, Sendable {
    case all(CGFloat)
    case symmetric(vertical: CGFloat?, horizontal: CGFloat?)
    case individual(top: CGFloat?, bottom: CGFloat?, leading: CGFloat?, trailing: CGFloat?)
    
    public init(from decoder: Decoder) throws {
        // Try single value first
        if let container = try? decoder.singleValueContainer(),
           let value = try? container.decode(CGFloat.self) {
            self = .all(value)
            return
        }
        
        // Try object
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.vertical) || container.contains(.horizontal) {
            let vertical = try container.decodeIfPresent(CGFloat.self, forKey: .vertical)
            let horizontal = try container.decodeIfPresent(CGFloat.self, forKey: .horizontal)
            self = .symmetric(vertical: vertical, horizontal: horizontal)
        } else {
            let top = try container.decodeIfPresent(CGFloat.self, forKey: .top)
            let bottom = try container.decodeIfPresent(CGFloat.self, forKey: .bottom)
            let leading = try container.decodeIfPresent(CGFloat.self, forKey: .leading)
            let trailing = try container.decodeIfPresent(CGFloat.self, forKey: .trailing)
            self = .individual(top: top, bottom: bottom, leading: leading, trailing: trailing)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case vertical, horizontal, top, bottom, leading, trailing
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .all(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .symmetric(let vertical, let horizontal):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(vertical, forKey: .vertical)
            try container.encodeIfPresent(horizontal, forKey: .horizontal)
        case .individual(let top, let bottom, let leading, let trailing):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(top, forKey: .top)
            try container.encodeIfPresent(bottom, forKey: .bottom)
            try container.encodeIfPresent(leading, forKey: .leading)
            try container.encodeIfPresent(trailing, forKey: .trailing)
        }
    }
    
    // Helper to get EdgeInsets
    public var edgeInsets: EdgeInsets {
        switch self {
        case .all(let value):
            return EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
        case .symmetric(let vertical, let horizontal):
            return EdgeInsets(
                top: vertical ?? 0,
                leading: horizontal ?? 0,
                bottom: vertical ?? 0,
                trailing: horizontal ?? 0
            )
        case .individual(let top, let bottom, let leading, let trailing):
            return EdgeInsets(
                top: top ?? 0,
                leading: leading ?? 0,
                bottom: bottom ?? 0,
                trailing: trailing ?? 0
            )
        }
    }
}

// MARK: - Style Properties

public struct StyleProperties: Codable, Sendable {
    public var backgroundColor: String?
    public var backgroundGradient: GradientStyle?
    public var borderRadius: BorderRadiusValue?
    public var borderWidth: CGFloat?
    public var borderColor: String?
    public var shadow: ShadowStyle?
    public var opacity: CGFloat?
}

public struct GradientStyle: Codable, Sendable {
    public let type: GradientType
    public let colors: [String]
    public var angle: CGFloat?
    
    public enum GradientType: String, Codable, Sendable {
        case linear
        case radial
    }
}

public enum BorderRadiusValue: Codable, Sendable {
    case all(CGFloat)
    case corners(topLeading: CGFloat?, topTrailing: CGFloat?, bottomLeading: CGFloat?, bottomTrailing: CGFloat?)
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let value = try? container.decode(CGFloat.self) {
            self = .all(value)
            return
        }
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let topLeading = try container.decodeIfPresent(CGFloat.self, forKey: .topLeading)
        let topTrailing = try container.decodeIfPresent(CGFloat.self, forKey: .topTrailing)
        let bottomLeading = try container.decodeIfPresent(CGFloat.self, forKey: .bottomLeading)
        let bottomTrailing = try container.decodeIfPresent(CGFloat.self, forKey: .bottomTrailing)
        self = .corners(topLeading: topLeading, topTrailing: topTrailing, bottomLeading: bottomLeading, bottomTrailing: bottomTrailing)
    }
    
    private enum CodingKeys: String, CodingKey {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .all(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .corners(let topLeading, let topTrailing, let bottomLeading, let bottomTrailing):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(topLeading, forKey: .topLeading)
            try container.encodeIfPresent(topTrailing, forKey: .topTrailing)
            try container.encodeIfPresent(bottomLeading, forKey: .bottomLeading)
            try container.encodeIfPresent(bottomTrailing, forKey: .bottomTrailing)
        }
    }
    
    public var cornerRadius: CGFloat {
        switch self {
        case .all(let value): return value
        case .corners(let tl, let tr, let bl, let br):
            return max(tl ?? 0, tr ?? 0, bl ?? 0, br ?? 0)
        }
    }
}

public struct ShadowStyle: Codable, Sendable {
    public var color: String?
    public let radius: CGFloat
    public var x: CGFloat?
    public var y: CGFloat?
}

// MARK: - Content Properties

public struct ContentProperties: Codable, Sendable {
    // Text
    public var text: String?
    public var textVariant: TextVariant?
    public var textAlign: TextAlign?
    public var textColor: String?
    public var fontWeight: FontWeight?
    public var fontSize: CGFloat?
    public var fontFamily: String?        // Custom font family name
    public var lineHeight: CGFloat?       // Line height multiplier
    public var letterSpacing: CGFloat?    // Letter spacing in points
    public var lineLimit: Int?
    
    // Icon
    public var icon: String?
    public var iconSize: IconSize?
    public var iconColor: String?
    
    // Image
    public var src: String?
    public var alt: String?
    public var contentMode: ContentMode?
    public var placeholder: String?
    
    // Button
    public var buttonText: String?
    public var buttonVariant: ButtonVariant?
    public var buttonAction: LayoutButtonAction?
    public var buttonIcon: String?
    public var buttonIconPosition: IconPosition?
    public var buttonTextColor: String?  // Custom text color for buttons
    public var fullWidth: Bool?
    
    // Input
    public var inputPlaceholder: String?
    public var inputLabel: String?
    public var inputType: InputType?
    public var inputFieldName: String?
    public var required: Bool?
    
    // Checklist
    public var checklistItems: [ChecklistItemData]?
    public var allowMultiple: Bool?
    public var minSelections: Int?
    public var maxSelections: Int?
    public var checklistStyle: ChecklistStyle?
    public var checklistAction: LayoutButtonAction?
    public var autoAdvance: Bool?
    public var activeColor: String?
    // Checklist styling
    public var checklistFontSize: CGFloat?      // Font size for items
    public var checklistItemPadding: CGFloat?   // Padding inside each item
    public var checklistItemGap: CGFloat?       // Gap between items
    public var checklistBorderRadius: CGFloat?  // Corner radius for items
    public var checklistColumns: Int?           // 1 or 2 column layout
    
    // Progress
    public var progressVariant: ProgressVariant?
    public var progressValue: CGFloat?
    public var fillColor: String?
    public var trackColor: String?
    
    // Divider
    public var dividerColor: String?
    public var dividerThickness: CGFloat?
    
    // Video
    public var videoSrc: String?
    public var videoPoster: String?
    public var autoplay: Bool?
    public var loop: Bool?
    public var muted: Bool?
    public var showControls: Bool?
    
    // Lottie
    public var lottieSrc: String?
    public var lottieAutoplay: Bool?
    public var lottieLoop: Bool?
    
    // Custom
    public var customIdentifier: String?
    public var customProps: [String: AnyCodableValue]?
    
    // Spacer
    public var spacerSize: CGFloat?
    public var spacerFlex: CGFloat?
    public var spacerMinSize: CGFloat?

    // MARK: - Slider
    public var sliderFieldName: String?
    public var sliderFieldLabel: String?
    public var sliderMin: CGFloat?
    public var sliderMax: CGFloat?
    public var sliderStep: CGFloat?
    public var sliderDefaultValue: CGFloat?
    public var sliderShowValue: Bool?
    public var sliderValuePrefix: String?
    public var sliderValueSuffix: String?
    public var sliderShowMinMax: Bool?
    public var sliderThumbColor: String?
    public var sliderValueFontSize: CGFloat?
    public var sliderSuffixFontSize: CGFloat?

    // MARK: - Picker
    public var pickerFieldName: String?
    public var pickerFieldLabel: String?
    public var pickerPreset: PickerPreset?
    public var pickerColumns: [PickerColumnData]?
    public var pickerDefaultValue: AnyCodableValue?
    public var pickerHeight: CGFloat?
    public var pickerItemHeight: CGFloat?
    public var pickerHighlightColor: String?
    public var pickerSelectedTextColor: String?

    // MARK: - Review
    public var reviewType: ReviewType?
    public var reviewMaxRating: Int?
    public var reviewEmojis: [String]?
    public var reviewDefaultRating: Int?
    public var reviewRatingFieldName: String?
    public var reviewTextFieldName: String?
    public var reviewShowTextInput: Bool?
    public var reviewTextPlaceholder: String?
    public var reviewStarColor: String?
    public var reviewStarEmptyColor: String?
    public var reviewSize: ReviewSize?

    // MARK: - Sticker
    public var stickerText: String?
    public var stickerVariant: StickerVariant?
    public var stickerSize: StickerSize?
    public var stickerRotation: CGFloat?

    // MARK: - Loading Indicator
    public var loadingVariant: LoadingVariant?
    public var loadingDuration: Int?
    public var loadingMessages: [LoadingMessage]?
    public var loadingShowPercentage: Bool?
    public var loadingSize: CGFloat?
    public var loadingStrokeWidth: CGFloat?
    public var loadingGradientColors: [String]?
    public var loadingMessageColor: String?
    public var loadingMessageFontSize: CGFloat?
    public var loadingPercentageColor: String?
    public var loadingPercentageFontSize: CGFloat?

    // MARK: - Feature Card
    public var featureHeadline: String?
    public var featureBody: String?
    public var featureHeadlineColor: String?
    public var featureBodyColor: String?
    public var featureHeadlineFontSize: CGFloat?
    public var featureBodyFontSize: CGFloat?
    public var featureHeadlineFontWeight: FontWeight?
    public var featureBodyFontWeight: FontWeight?
    public var featureAlign: TextAlign?
    public var featureGlowingBorder: Bool?
    public var featureGlowColor: String?
    public var featureGlowIntensity: CGFloat?
    public var featureHeadlineBodyGap: CGFloat?
}

public enum TextVariant: String, Codable, Sendable {
    case h1, h2, h3, body, caption, label
}

public enum TextAlign: String, Codable, Sendable {
    case leading, center, trailing
}

public enum FontWeight: String, Codable, Sendable {
    case regular, medium, semibold, bold
}

public enum IconSize: Codable, Sendable {
    case preset(String)
    case custom(CGFloat)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(CGFloat.self) {
            self = .custom(number)
        } else if let string = try? container.decode(String.self) {
            self = .preset(string)
        } else {
            self = .preset("md")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .preset(let value): try container.encode(value)
        case .custom(let value): try container.encode(value)
        }
    }
    
    public var cgFloat: CGFloat {
        switch self {
        case .preset(let size):
            switch size {
            case "sm": return 24
            case "md": return 32
            case "lg": return 48
            case "xl": return 64
            case "2xl": return 80
            default: return 48
            }
        case .custom(let value):
            return value
        }
    }
}

public enum ContentMode: String, Codable, Sendable {
    case fit, fill, center
}

public enum ButtonVariant: String, Codable, Sendable {
    case primary, secondary, outline, ghost
}

public enum IconPosition: String, Codable, Sendable {
    case leading, trailing
}

public enum InputType: String, Codable, Sendable {
    case text, email, number, password
}

public enum ChecklistStyle: String, Codable, Sendable {
    case list, pills, cards
}

public enum ProgressVariant: String, Codable, Sendable {
    case bar, dots, steps, ring
}

public struct ChecklistItemData: Codable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public var icon: String?
    public var description: String?
}

// MARK: - Picker Types

public enum PickerPreset: String, Codable, Sendable {
    case date
    case dateOfBirth = "date-of-birth"
    case age
    case weight
    case height
    case time
    case custom
}

public struct PickerColumnData: Codable, Sendable {
    public let id: String
    public var label: String?
    public let type: PickerColumnType
    public var items: [PickerItemData]?
    public var min: Int?
    public var max: Int?
    public var step: Int?
    public var prefix: String?
    public var suffix: String?
    public var width: CGFloat?
    public var align: TextAlign?

    public enum PickerColumnType: String, Codable, Sendable {
        case list
        case range
    }
}

public struct PickerItemData: Codable, Sendable {
    public let label: String
    public let value: AnyCodableValue
}

// MARK: - Review Types

public enum ReviewType: String, Codable, Sendable {
    case stars
    case emoji
}

public enum ReviewSize: String, Codable, Sendable {
    case sm, md, lg

    public var cgFloat: CGFloat {
        switch self {
        case .sm: return 24
        case .md: return 32
        case .lg: return 44
        }
    }
}

// MARK: - Sticker Types

public enum StickerVariant: String, Codable, Sendable {
    case badge
    case ribbon
    case circle
    case burst
}

public enum StickerSize: String, Codable, Sendable {
    case sm, md, lg

    public var fontSize: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 16
        case .lg: return 20
        }
    }

    public var padding: CGFloat {
        switch self {
        case .sm: return 8
        case .md: return 12
        case .lg: return 16
        }
    }
}

// MARK: - Loading Types

public enum LoadingVariant: String, Codable, Sendable {
    case circular
    case bar
    case dots
}

public struct LoadingMessage: Codable, Sendable {
    public let text: String
    public var atPercent: Int?
}

// Button action for layout system
public enum LayoutButtonAction: Codable, Sendable {
    case next
    case previous
    case screen(screenId: String)
    case complete
    case custom(identifier: String)
    
    enum CodingKeys: String, CodingKey {
        case type, screenId, identifier
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "next": self = .next
        case "previous": self = .previous
        case "screen":
            let screenId = try container.decode(String.self, forKey: .screenId)
            self = .screen(screenId: screenId)
        case "complete": self = .complete
        case "custom":
            let identifier = try container.decode(String.self, forKey: .identifier)
            self = .custom(identifier: identifier)
        default: self = .next
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .next: try container.encode("next", forKey: .type)
        case .previous: try container.encode("previous", forKey: .type)
        case .screen(let screenId):
            try container.encode("screen", forKey: .type)
            try container.encode(screenId, forKey: .screenId)
        case .complete: try container.encode("complete", forKey: .type)
        case .custom(let identifier):
            try container.encode("custom", forKey: .type)
            try container.encode(identifier, forKey: .identifier)
        }
    }
}

// MARK: - Animation Properties

public struct AnimationProperties: Codable, Sendable {
    public let type: AnimationType
    public var duration: Int?
    public var delay: Int?
    public var easing: EasingType?
    
    public enum AnimationType: String, Codable, Sendable {
        case fade
        case slideUp
        case slideDown
        case slideLeading
        case slideTrailing
        case scale
        case none
    }
    
    public enum EasingType: String, Codable, Sendable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case spring
    }
}

// MARK: - Accessibility Properties

public struct AccessibilityProperties: Codable, Sendable {
    public var label: String?
    public var hint: String?
    public var isButton: Bool?
    public var isHeader: Bool?
    public var hidden: Bool?
}

// MARK: - Screen Layout

public struct ScreenLayout: Codable, Sendable {
    public let version: Int
    public let root: LayoutNode
    public var backgroundColor: String?
    public var backgroundGradient: GradientStyle?
    public var backgroundImage: String?
    public var safeAreaMode: SafeAreaMode?
    
    public enum SafeAreaMode: String, Codable, Sendable {
        case respect
        case ignore
        case ignoreTop
        case ignoreBottom
    }
}

// MARK: - Flow Bundle (Delivered to SDK)

public struct FlowBundle: Codable, Sendable {
    public let bundleVersion: Int
    public let schemaVersion: Int
    public let flowId: String
    public let flowName: String
    public let screens: [ScreenBundle]
    public var progressIndicator: LayoutProgressIndicator?
    public var experiment: ExperimentInfo?
}

public struct ScreenBundle: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: ScreenBundleType
    public let order: Int
    public let layout: ScreenLayout
    
    public enum ScreenBundleType: String, Codable, Sendable {
        case welcome, feature, permission, celebration, native
    }
}

public struct LayoutProgressIndicator: Codable, Sendable {
    public let enabled: Bool
    public var variant: ProgressIndicatorVariant?
    public var position: ProgressIndicatorPosition?
    public var fillColor: String?
    public var trackColor: String?
    
    public enum ProgressIndicatorVariant: String, Codable, Sendable {
        case bar, dots, steps, minimal
    }
    
    public enum ProgressIndicatorPosition: String, Codable, Sendable {
        case top, bottom
    }
}

public struct ExperimentInfo: Codable, Sendable {
    public let id: String
    public let variantId: String
    public let variantName: String
    
    public init(id: String, variantId: String, variantName: String) {
        self.id = id
        self.variantId = variantId
        self.variantName = variantName
    }
}

// MARK: - Any Codable Value (for custom props)

public enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

