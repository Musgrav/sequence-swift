// Sequence Models
// Matches the backend TypeScript types

import Foundation

// MARK: - Onboarding Configuration

public struct OnboardingConfig: Codable, Sendable {
    public let version: Int
    public let screens: [Screen]
    public let experiment: ExperimentInfo?
    
    public init(version: Int, screens: [Screen], experiment: ExperimentInfo? = nil) {
        self.version = version
        self.screens = screens
        self.experiment = experiment
    }
}

public struct ExperimentInfo: Codable, Sendable {
    public let id: String
    public let variant: String
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
    case screen(screenId: String)
    case complete
    
    enum CodingKeys: String, CodingKey {
        case type
        case screenId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "next":
            self = .next
        case "screen":
            let screenId = try container.decode(String.self, forKey: .screenId)
            self = .screen(screenId: screenId)
        case "complete":
            self = .complete
        default:
            self = .next
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .next:
            try container.encode("next", forKey: .type)
        case .screen(let screenId):
            try container.encode("screen", forKey: .type)
            try container.encode(screenId, forKey: .screenId)
        case .complete:
            try container.encode("complete", forKey: .type)
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
    
    public init(id: String, type: ContentBlockType, order: Int, visible: Bool? = nil, animation: BlockAnimation? = nil, content: BlockContent) {
        self.id = id
        self.type = type
        self.order = order
        self.visible = visible
        self.animation = animation
        self.content = content
    }
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
    
    // Custom
    public var identifier: String?
    public var props: [String: AnyCodable]?
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
    case screenViewed = "screen_viewed"
    case screenCompleted = "screen_completed"
    case screenSkipped = "screen_skipped"
    case buttonTapped = "button_tapped"
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
}

public struct OnboardingEvent: Codable, Sendable {
    public let eventType: String
    public let screenId: String?
    public let userId: String
    public let deviceId: String
    public let timestamp: String
    public let properties: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case eventType, screenId, userId, deviceId, timestamp, properties
    }
    
    public init(eventType: String, screenId: String?, userId: String, deviceId: String, timestamp: String, properties: [String: Any]?) {
        self.eventType = eventType
        self.screenId = screenId
        self.userId = userId
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.properties = properties
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try container.decode(String.self, forKey: .eventType)
        screenId = try container.decodeIfPresent(String.self, forKey: .screenId)
        userId = try container.decode(String.self, forKey: .userId)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        properties = nil // Properties decoded separately if needed
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(screenId, forKey: .screenId)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode properties as [String: AnyCodable]
        if let props = properties {
            let encodableProps = props.mapValues { AnyCodable($0) }
            try container.encode(encodableProps, forKey: .properties)
        }
    }
}

