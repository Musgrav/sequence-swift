// Sequence Models
// Matches the backend TypeScript types

import Foundation

// MARK: - Onboarding Configuration

public struct OnboardingConfig: Codable, Sendable {
    public let version: Int
    public let screens: [Screen]
    public let experiment: ExperimentInfo?
    public let progressIndicator: FlowProgressIndicator?
    
    public init(version: Int, screens: [Screen], experiment: ExperimentInfo? = nil, progressIndicator: FlowProgressIndicator? = nil) {
        self.version = version
        self.screens = screens
        self.experiment = experiment
        self.progressIndicator = progressIndicator
    }
}

// Flow-level progress indicator settings
public struct FlowProgressIndicator: Codable, Sendable {
    public let enabled: Bool
    public let variant: ProgressVariant?
    public let position: ProgressPosition?
    public let fillColor: String?
    public let trackColor: String?
    public let animated: Bool?
    public let startScreen: Int?   // Starting screen index (0-based, defaults to 0)
    public let endScreen: Int?     // Ending screen index (0-based, defaults to totalScreens - 1)
    
    public enum ProgressVariant: String, Codable, Sendable {
        case bar
        case dots
        case steps
        case minimal
    }
    
    public enum ProgressPosition: String, Codable, Sendable {
        case top
        case bottom
    }
}


// MARK: - Screen

public struct Screen: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: ScreenType
    public let order: Int
    public let content: ScreenContent
    
    public init(id: String, name: String, type: ScreenType, order: Int, content: ScreenContent) {
        self.id = id
        self.name = name
        self.type = type
        self.order = order
        self.content = content
    }
}

public enum ScreenType: String, Codable, Sendable {
    case welcome
    case feature
    case carousel
    case permission
    case celebration
    case native
}

// MARK: - Screen Content

public struct ScreenContent: Codable, Sendable {
    // Legacy simple fields
    public var title: String?
    public var subtitle: String?
    public var body: String?
    public var image: String?
    public var backgroundColor: String?
    public var titleColor: String?
    public var subtitleColor: String?
    public var buttonText: String?
    public var buttonColor: String?
    public var buttonTextColor: String?
    public var buttonAction: ButtonAction?
    public var icon: String?
    
    // Block-based content
    public var blocks: [ContentBlock]?
    public var useBlocks: Bool?
    
    // Background options
    public var backgroundGradient: BackgroundGradient?
    public var backgroundImage: String?
    public var backgroundOverlay: String?
    
    // Carousel specific
    public var slides: [CarouselSlide]?
    
    // Permission specific
    public var permissionType: String?
    public var skipText: String?
    public var skipAction: ButtonAction?
    
    // Native specific
    public var identifier: String?
    
    public init(
        title: String? = nil,
        subtitle: String? = nil,
        body: String? = nil,
        image: String? = nil,
        backgroundColor: String? = nil,
        titleColor: String? = nil,
        subtitleColor: String? = nil,
        buttonText: String? = nil,
        buttonColor: String? = nil,
        buttonTextColor: String? = nil,
        buttonAction: ButtonAction? = nil,
        icon: String? = nil,
        blocks: [ContentBlock]? = nil,
        useBlocks: Bool? = nil,
        backgroundGradient: BackgroundGradient? = nil,
        backgroundImage: String? = nil,
        backgroundOverlay: String? = nil,
        slides: [CarouselSlide]? = nil,
        permissionType: String? = nil,
        skipText: String? = nil,
        skipAction: ButtonAction? = nil,
        identifier: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.image = image
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.buttonText = buttonText
        self.buttonColor = buttonColor
        self.buttonTextColor = buttonTextColor
        self.buttonAction = buttonAction
        self.icon = icon
        self.blocks = blocks
        self.useBlocks = useBlocks
        self.backgroundGradient = backgroundGradient
        self.backgroundImage = backgroundImage
        self.backgroundOverlay = backgroundOverlay
        self.slides = slides
        self.permissionType = permissionType
        self.skipText = skipText
        self.skipAction = skipAction
        self.identifier = identifier
    }
}

// MARK: - Button Action

public enum ButtonAction: Codable, Sendable {
    case next
    case previous
    case screen(screenId: String)
    case complete
    case custom(identifier: String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case screenId
        case identifier
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "next":
            self = .next
        case "previous":
            self = .previous
        case "screen":
            let screenId = try container.decode(String.self, forKey: .screenId)
            self = .screen(screenId: screenId)
        case "complete":
            self = .complete
        case "custom":
            let identifier = try container.decode(String.self, forKey: .identifier)
            self = .custom(identifier: identifier)
        default:
            self = .next
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .next:
            try container.encode("next", forKey: .type)
        case .previous:
            try container.encode("previous", forKey: .type)
        case .screen(let screenId):
            try container.encode("screen", forKey: .type)
            try container.encode(screenId, forKey: .screenId)
        case .complete:
            try container.encode("complete", forKey: .type)
        case .custom(let identifier):
            try container.encode("custom", forKey: .type)
            try container.encode(identifier, forKey: .identifier)
        }
    }
}

// MARK: - Background Gradient

public struct BackgroundGradient: Codable, Sendable {
    public let type: GradientType
    public let colors: [String]
    public let angle: Int?
    
    public enum GradientType: String, Codable, Sendable {
        case linear
        case radial
    }
}

// MARK: - Carousel Slide

public struct CarouselSlide: Codable, Sendable {
    public let icon: String?
    public let image: String?
    public let title: String
    public let body: String
}

// MARK: - Content Blocks

public struct ContentBlock: Codable, Identifiable, Sendable {
    public let id: String
    public let type: ContentBlockType
    public let order: Int
    public var visible: Bool?
    public var animation: BlockAnimation?
    public var content: BlockContent
    public var position: BlockPosition?  // Absolute positioning for free-form layout
    public var styling: BlockStyling?    // Additional styling options
    
    enum CodingKeys: String, CodingKey {
        case id, type, order, visible, animation, content, position, styling
    }
    
    public init(id: String, type: ContentBlockType, order: Int, visible: Bool? = nil, animation: BlockAnimation? = nil, content: BlockContent, position: BlockPosition? = nil, styling: BlockStyling? = nil) {
        self.id = id
        self.type = type
        self.order = order
        self.visible = visible
        self.animation = animation
        self.content = content
        self.position = position
        self.styling = styling
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(ContentBlockType.self, forKey: .type)
        order = try container.decode(Int.self, forKey: .order)
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible)
        animation = try container.decodeIfPresent(BlockAnimation.self, forKey: .animation)
        content = try container.decode(BlockContent.self, forKey: .content)
        position = try container.decodeIfPresent(BlockPosition.self, forKey: .position)
        styling = try container.decodeIfPresent(BlockStyling.self, forKey: .styling)
        
        // Debug logging for position decoding
        if let pos = position {
            print("🔧 [Sequence SDK] Decoded block '\(type)' position: (\(pos.x), \(pos.y))")
        } else {
            print("🔧 [Sequence SDK] Decoded block '\(type)' - NO POSITION")
        }
    }
}

// MARK: - Block Position (for absolute positioning)

public struct BlockPosition: Codable, Sendable {
    public let x: CGFloat
    public let y: CGFloat
    
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both Int and Double from JSON
        if let intX = try? container.decode(Int.self, forKey: .x) {
            x = CGFloat(intX)
        } else {
            x = CGFloat(try container.decode(Double.self, forKey: .x))
        }
        
        if let intY = try? container.decode(Int.self, forKey: .y) {
            y = CGFloat(intY)
        } else {
            y = CGFloat(try container.decode(Double.self, forKey: .y))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Double(x), forKey: .x)
        try container.encode(Double(y), forKey: .y)
    }
}

// MARK: - Block Styling

public struct BlockStyling: Codable, Sendable {
    public var paddingTop: CGFloat?
    public var paddingBottom: CGFloat?
    public var paddingLeft: CGFloat?
    public var paddingRight: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var marginLeft: CGFloat?
    public var marginRight: CGFloat?
    public var width: DimensionValue?
    public var height: DimensionValue?
    public var minWidth: CGFloat?
    public var maxWidth: CGFloat?
    public var borderRadius: Int?
    public var borderWidth: CGFloat?
    public var borderColor: String?
    public var backgroundColor: String?
    public var opacity: CGFloat?
}

public enum ContentBlockType: String, Codable, Sendable {
    case text
    case image
    case video
    case lottie
    case icon
    case button
    case spacer
    case divider
    case input
    case checklist
    case progress
    case custom
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ContentBlockType(rawValue: rawValue) ?? .unknown
    }
}

public struct BlockAnimation: Codable, Sendable {
    public let type: AnimationType
    public let delay: Int?
    public let duration: Int?
    
    public enum AnimationType: String, Codable, Sendable {
        case fade
        case slideUp = "slide-up"
        case slideDown = "slide-down"
        case slideLeft = "slide-left"
        case slideRight = "slide-right"
        case scale
        case bounce
        case none
    }
}

// MARK: - Block Content (Union Type)

public struct BlockContent: Codable, Sendable {
    // Text & Button (shared: variant is used by both)
    public var text: String?
    public var variant: String?
    public var color: String?
    public var align: String?
    public var fontWeight: String?
    // Typography (new)
    public var fontFamily: String?
    public var fontSizeValue: CGFloat?  // Custom font size in pixels
    public var lineHeight: CGFloat?
    public var letterSpacing: CGFloat?
    
    // Image & Spacer (shared: height is used by both)
    public var src: String?
    public var alt: String?
    public var width: DimensionValue?
    public var height: DimensionValue?
    public var borderRadius: Int?
    public var objectFit: String?
    
    // Video
    public var poster: String?
    public var autoplay: Bool?
    public var loop: Bool?
    public var muted: Bool?
    public var controls: Bool?
    
    // Icon
    public var icon: String?
    public var size: String?
    
    // Button
    public var action: ButtonAction?
    public var fullWidth: Bool?
    public var backgroundColor: String?
    public var textColor: String?
    public var preset: String?           // Button preset: 'sign-in-apple', 'sign-in-google', 'sign-in-email', etc.
    public var iconPosition: String?     // 'left' or 'right'
    
    // Divider
    public var thickness: Int?
    public var style: String?
    
    // Input
    public var placeholder: String?
    public var label: String?
    public var inputType: String?
    public var required: Bool?
    public var fieldName: String?
    
    // Checklist
    public var items: [ChecklistItem]?
    public var allowMultiple: Bool?
    public var minSelections: Int?
    public var maxSelections: Int?
    public var autoAdvance: Bool?
    public var checklistStyle: String?   // 'list', 'pills', 'cards'
    public var columns: Int?             // 1 or 2
    public var activeColor: String?      // Color when selected
    public var inactiveColor: String?    // Color when not selected
    // Checklist styling options
    public var fontSize: Int?            // Font size in pixels
    public var itemPadding: Int?         // Padding inside each item
    public var itemGap: Int?             // Gap between items
    public var itemBorderRadius: Int?    // Corner radius for items (uses borderRadius if not set)
    public var itemWidth: DimensionValue? // Width of each item
    
    // Custom
    public var identifier: String?
    public var props: [String: AnyCodable]?

    // Spacer flex (for flexible spacers that fill available space)
    public var flex: Bool?

    // Coding keys - 'style' is shared between divider and checklist
    enum CodingKeys: String, CodingKey {
        case text, variant, color, align, fontWeight
        case fontFamily, fontSize, lineHeight, letterSpacing
        case src, alt, width, height, borderRadius, objectFit
        case poster, autoplay, loop, muted, controls
        case icon, size
        case action, fullWidth, backgroundColor, textColor, preset, iconPosition
        case thickness
        case placeholder, label, inputType, required, fieldName
        case items, allowMultiple, minSelections, maxSelections, autoAdvance
        case checklistStyle = "style"  // 'style' JSON key used by both divider and checklist
        case columns, activeColor, inactiveColor
        case itemPadding, itemGap, itemBorderRadius, itemWidth
        case identifier, props
        case flex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        text = try container.decodeIfPresent(String.self, forKey: .text)
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        align = try container.decodeIfPresent(String.self, forKey: .align)
        fontWeight = try container.decodeIfPresent(String.self, forKey: .fontWeight)
        
        // Typography properties
        fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily)
        
        // fontSize can be Int, Double, or String in JSON (handle all cases)
        if let intSize = try? container.decodeIfPresent(Int.self, forKey: .fontSize) {
            fontSizeValue = CGFloat(intSize)
            fontSize = intSize
        } else if let doubleSize = try? container.decodeIfPresent(Double.self, forKey: .fontSize) {
            fontSizeValue = CGFloat(doubleSize)
            fontSize = Int(doubleSize)
        } else if let stringSize = try? container.decodeIfPresent(String.self, forKey: .fontSize),
                  let parsed = Double(stringSize) {
            // Handle case where fontSize is stored as a string
            fontSizeValue = CGFloat(parsed)
            fontSize = Int(parsed)
        }
        
        // lineHeight and letterSpacing can also be Int, Double, or String
        if let lh = try? container.decodeIfPresent(CGFloat.self, forKey: .lineHeight) {
            lineHeight = lh
        } else if let lhInt = try? container.decodeIfPresent(Int.self, forKey: .lineHeight) {
            lineHeight = CGFloat(lhInt)
        } else if let lhStr = try? container.decodeIfPresent(String.self, forKey: .lineHeight),
                  let parsed = Double(lhStr) {
            lineHeight = CGFloat(parsed)
        }
        
        if let ls = try? container.decodeIfPresent(CGFloat.self, forKey: .letterSpacing) {
            letterSpacing = ls
        } else if let lsInt = try? container.decodeIfPresent(Int.self, forKey: .letterSpacing) {
            letterSpacing = CGFloat(lsInt)
        } else if let lsStr = try? container.decodeIfPresent(String.self, forKey: .letterSpacing),
                  let parsed = Double(lsStr) {
            letterSpacing = CGFloat(parsed)
        }
        
        // Debug: log what we decoded for typography
        if text != nil {
            print("🔧 [BlockContent] Decoded text block:")
            print("🔧 [BlockContent]   - text: '\(text?.prefix(20) ?? "nil")...'")
            print("🔧 [BlockContent]   - fontFamily: \(fontFamily ?? "nil")")
            print("🔧 [BlockContent]   - fontSize: \(fontSizeValue.map { "\($0)" } ?? "nil")")
            print("🔧 [BlockContent]   - fontWeight: \(fontWeight ?? "nil")")
            print("🔧 [BlockContent]   - variant: \(variant ?? "nil")")
        }
        
        src = try container.decodeIfPresent(String.self, forKey: .src)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
        width = try container.decodeIfPresent(DimensionValue.self, forKey: .width)
        height = try container.decodeIfPresent(DimensionValue.self, forKey: .height)
        borderRadius = try container.decodeIfPresent(Int.self, forKey: .borderRadius)
        objectFit = try container.decodeIfPresent(String.self, forKey: .objectFit)
        
        poster = try container.decodeIfPresent(String.self, forKey: .poster)
        autoplay = try container.decodeIfPresent(Bool.self, forKey: .autoplay)
        loop = try container.decodeIfPresent(Bool.self, forKey: .loop)
        muted = try container.decodeIfPresent(Bool.self, forKey: .muted)
        controls = try container.decodeIfPresent(Bool.self, forKey: .controls)
        
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        
        action = try container.decodeIfPresent(ButtonAction.self, forKey: .action)
        fullWidth = try container.decodeIfPresent(Bool.self, forKey: .fullWidth)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor)
        preset = try container.decodeIfPresent(String.self, forKey: .preset)
        iconPosition = try container.decodeIfPresent(String.self, forKey: .iconPosition)
        
        thickness = try container.decodeIfPresent(Int.self, forKey: .thickness)
        // 'style' JSON key is decoded via checklistStyle (used by both divider and checklist)
        style = try container.decodeIfPresent(String.self, forKey: .checklistStyle)
        
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        inputType = try container.decodeIfPresent(String.self, forKey: .inputType)
        required = try container.decodeIfPresent(Bool.self, forKey: .required)
        fieldName = try container.decodeIfPresent(String.self, forKey: .fieldName)
        
        items = try container.decodeIfPresent([ChecklistItem].self, forKey: .items)
        allowMultiple = try container.decodeIfPresent(Bool.self, forKey: .allowMultiple)
        minSelections = try container.decodeIfPresent(Int.self, forKey: .minSelections)
        maxSelections = try container.decodeIfPresent(Int.self, forKey: .maxSelections)
        autoAdvance = try container.decodeIfPresent(Bool.self, forKey: .autoAdvance)
        // 'style' is used for both divider and checklist, stored in checklistStyle
        checklistStyle = try container.decodeIfPresent(String.self, forKey: .checklistStyle)
        columns = try container.decodeIfPresent(Int.self, forKey: .columns)
        activeColor = try container.decodeIfPresent(String.self, forKey: .activeColor)
        inactiveColor = try container.decodeIfPresent(String.self, forKey: .inactiveColor)
        // fontSize already decoded above for typography
        itemPadding = try container.decodeIfPresent(Int.self, forKey: .itemPadding)
        itemGap = try container.decodeIfPresent(Int.self, forKey: .itemGap)
        itemBorderRadius = try container.decodeIfPresent(Int.self, forKey: .itemBorderRadius)
        itemWidth = try container.decodeIfPresent(DimensionValue.self, forKey: .itemWidth)
        
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        props = try container.decodeIfPresent([String: AnyCodable].self, forKey: .props)
        flex = try container.decodeIfPresent(Bool.self, forKey: .flex)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(variant, forKey: .variant)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(align, forKey: .align)
        try container.encodeIfPresent(fontWeight, forKey: .fontWeight)
        
        // Typography
        try container.encodeIfPresent(fontFamily, forKey: .fontFamily)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(lineHeight, forKey: .lineHeight)
        try container.encodeIfPresent(letterSpacing, forKey: .letterSpacing)
        
        try container.encodeIfPresent(src, forKey: .src)
        try container.encodeIfPresent(alt, forKey: .alt)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(borderRadius, forKey: .borderRadius)
        try container.encodeIfPresent(objectFit, forKey: .objectFit)
        
        try container.encodeIfPresent(poster, forKey: .poster)
        try container.encodeIfPresent(autoplay, forKey: .autoplay)
        try container.encodeIfPresent(loop, forKey: .loop)
        try container.encodeIfPresent(muted, forKey: .muted)
        try container.encodeIfPresent(controls, forKey: .controls)
        
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(size, forKey: .size)
        
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(fullWidth, forKey: .fullWidth)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(textColor, forKey: .textColor)
        try container.encodeIfPresent(preset, forKey: .preset)
        try container.encodeIfPresent(iconPosition, forKey: .iconPosition)
        
        try container.encodeIfPresent(thickness, forKey: .thickness)
        // Encode style using checklistStyle key (maps to 'style' in JSON)
        try container.encodeIfPresent(style, forKey: .checklistStyle)
        
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(inputType, forKey: .inputType)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(fieldName, forKey: .fieldName)
        
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(allowMultiple, forKey: .allowMultiple)
        try container.encodeIfPresent(minSelections, forKey: .minSelections)
        try container.encodeIfPresent(maxSelections, forKey: .maxSelections)
        try container.encodeIfPresent(autoAdvance, forKey: .autoAdvance)
        try container.encodeIfPresent(checklistStyle, forKey: .checklistStyle)
        try container.encodeIfPresent(columns, forKey: .columns)
        try container.encodeIfPresent(activeColor, forKey: .activeColor)
        try container.encodeIfPresent(inactiveColor, forKey: .inactiveColor)
        try container.encodeIfPresent(fontSize, forKey: .fontSize)
        try container.encodeIfPresent(itemPadding, forKey: .itemPadding)
        try container.encodeIfPresent(itemGap, forKey: .itemGap)
        try container.encodeIfPresent(itemBorderRadius, forKey: .itemBorderRadius)
        try container.encodeIfPresent(itemWidth, forKey: .itemWidth)
        
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(props, forKey: .props)
        try container.encodeIfPresent(flex, forKey: .flex)
    }
}

public struct ChecklistItem: Codable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public var checked: Bool?
}

// MARK: - Dimension Value (Int or String)

public enum DimensionValue: Codable, Sendable {
    case number(Int)
    case string(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .string("auto")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Any Codable (for custom props)

public struct AnyCodable: Codable, Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Events

public enum EventType: String, Sendable {
    case screenViewed = "screen_viewed"              // All screen views (for debugging/analytics)
    case screenFirstViewed = "screen_first_viewed"    // First time user views a screen (one per user per screen)
    case screenCompleted = "screen_completed"          // User moves past a screen
    case screenSkipped = "screen_skipped"              // User skips a screen
    case screenDroppedOff = "screen_dropped_off"      // User exits onboarding without completing (at this screen)
    case buttonTapped = "button_tapped"               // Button interaction
    case onboardingStarted = "onboarding_started"       // User starts onboarding flow
    case onboardingCompleted = "onboarding_completed"  // User completes entire flow
    case experimentVariantAssigned = "experiment_variant_assigned" // User assigned to A/B test variant
}

public struct OnboardingEvent: Codable, Sendable {
    public let eventType: String
    public let screenId: String?
    public let userId: String
    public let deviceId: String
    public let timestamp: String
    public let properties: [String: Any]?
    // Experiment tracking
    public let experimentId: String?
    public let variantId: String?
    
    enum CodingKeys: String, CodingKey {
        case eventType, screenId, userId, deviceId, timestamp, properties
        case experimentId = "experiment_id"
        case variantId = "variant_id"
    }
    
    public init(eventType: String, screenId: String?, userId: String, deviceId: String, timestamp: String, properties: [String: Any]?, experimentId: String? = nil, variantId: String? = nil) {
        self.eventType = eventType
        self.screenId = screenId
        self.userId = userId
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.properties = properties
        self.experimentId = experimentId
        self.variantId = variantId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(String.self, forKey: .eventType)
        screenId = try container.decodeIfPresent(String.self, forKey: .screenId)
        userId = try container.decode(String.self, forKey: .userId)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        properties = nil // Properties decoded separately if needed
        experimentId = try container.decodeIfPresent(String.self, forKey: .experimentId)
        variantId = try container.decodeIfPresent(String.self, forKey: .variantId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(screenId, forKey: .screenId)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(experimentId, forKey: .experimentId)
        try container.encodeIfPresent(variantId, forKey: .variantId)
        
        // Encode properties as [String: AnyCodable]
        if let props = properties {
            let encodableProps = props.mapValues { AnyCodable($0) }
            try container.encode(encodableProps, forKey: .properties)
        }
    }
}

