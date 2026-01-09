// Font Loading and Management for Sequence SDK
//
// Provides font loading utilities with iOS system font fallbacks
// Maps Google Fonts to closest iOS system fonts when custom fonts aren't available

import SwiftUI
import CoreText

/// Maps Google Font names to iOS system font equivalents
/// Based on web/src/lib/fonts.ts iosFontFallbacks
public let iosFontFallbacks: [String: String] = [
    // Sans-serif
    "Inter": ".AppleSystemUIFont",  // SF Pro
    "Roboto": "Helvetica Neue",
    "Open Sans": "Helvetica Neue",
    "Lato": "Helvetica Neue",
    "Montserrat": "Avenir Next",
    "Poppins": "Avenir",
    "Outfit": ".AppleSystemUIFont",
    "Plus Jakarta Sans": ".AppleSystemUIFont",
    "DM Sans": ".AppleSystemUIFont",
    "Nunito": "Avenir",
    "Raleway": "Avenir Next",
    "Work Sans": ".AppleSystemUIFont",
    "Source Sans Pro": "Helvetica Neue",
    "Manrope": ".AppleSystemUIFont",
    "Space Grotesk": "Avenir Next",
    "Urbanist": "Avenir",
    "Sora": ".AppleSystemUIFont",
    "Figtree": ".AppleSystemUIFont",
    "Geist": ".AppleSystemUIFont",
    "Archivo": "Helvetica Neue",
    "Rubik": "Avenir",
    "Karla": "Helvetica Neue",
    "Mulish": "Avenir",
    "Quicksand": "Avenir",
    "Cabin": "Avenir",
    "Exo 2": "Avenir Next",
    "Barlow": "Helvetica Neue",
    "Jost": "Avenir Next",
    "Red Hat Display": ".AppleSystemUIFont",
    "Albert Sans": ".AppleSystemUIFont",
    "General Sans": ".AppleSystemUIFont",
    "Satoshi": ".AppleSystemUIFont",
    "Onest": ".AppleSystemUIFont",
    "Bricolage Grotesque": "Avenir",
    "Lexend": "Avenir",
    "Wix Madefor Text": ".AppleSystemUIFont",
    "Be Vietnam Pro": "Helvetica Neue",
    "Hanken Grotesk": ".AppleSystemUIFont",
    "Instrument Sans": ".AppleSystemUIFont",

    // Serif
    "Playfair Display": "Georgia",
    "Merriweather": "Georgia",
    "Lora": "Georgia",
    "PT Serif": "Times New Roman",
    "Libre Baskerville": "Baskerville",
    "Cormorant": "Didot",
    "Crimson Text": "Georgia",
    "Source Serif Pro": "Georgia",
    "EB Garamond": "Apple Garamond",
    "Bitter": "Georgia",
    "Fraunces": "Georgia",
    "DM Serif Display": "Didot",
    "Newsreader": "Times New Roman",
    "Spectral": "Georgia",
    "Vollkorn": "Georgia",
    "Alegreya": "Georgia",
    "Cardo": "Times New Roman",
    "Bodoni Moda": "Didot",
    "Cormorant Garamond": "Apple Garamond",
    "Literata": "Georgia",
    "Noto Serif": "Georgia",
    "Instrument Serif": "Georgia",
    "Young Serif": "Georgia",
    "Libre Caslon Text": "Georgia",

    // Display
    "Bebas Neue": "Impact",
    "Anton": "Impact",
    "Oswald": "Helvetica Neue",
    "Abril Fatface": "Didot",
    "Lobster": "Snell Roundhand",
    "Righteous": "Futura",
    "Titan One": "Impact",
    "Alfa Slab One": "Rockwell",
    "Pacifico": "Snell Roundhand",
    "Permanent Marker": "Marker Felt",
    "Lilita One": "Impact",
    "Russo One": "Futura",
    "Passion One": "Impact",
    "Bungee": "Impact",
    "Bangers": "Marker Felt",
    "Fredoka One": "Futura",
    "Comfortaa": "Avenir",
    "Orbitron": "Futura",
    "Changa One": "Impact",
    "Black Ops One": "Futura",
    "Baloo 2": "Avenir",
    "Chewy": "Marker Felt",
    "Concert One": "Impact",
    "Staatliches": "Impact",
    "Dela Gothic One": "Impact",
    "Bowlby One SC": "Impact",
    "Bungee Shade": "Impact",
    "Monoton": "Didot",
    "Audiowide": "Futura",
    "Climate Crisis": "Impact",
    "Rubik Mono One": "Futura",
    "Shrikhand": "Impact",
    "Rampart One": "Impact",
    "Protest Strike": "Impact",

    // Handwriting
    "Caveat": "Bradley Hand",
    "Dancing Script": "Snell Roundhand",
    "Parisienne": "Snell Roundhand",
    "Great Vibes": "Snell Roundhand",
    "Sacramento": "Snell Roundhand",
    "Satisfy": "Snell Roundhand",
    "Kaushan Script": "Snell Roundhand",
    "Alex Brush": "Snell Roundhand",
    "Allura": "Snell Roundhand",
    "Amatic SC": "Marker Felt",
    "Shadows Into Light": "Noteworthy",
    "Indie Flower": "Noteworthy",
    "Patrick Hand": "Bradley Hand",
    "Architects Daughter": "Noteworthy",
    "Homemade Apple": "Bradley Hand",
    "Handlee": "Bradley Hand",
    "Leckerli One": "Snell Roundhand",
    "Rock Salt": "Marker Felt",
    "Reenie Beanie": "Noteworthy",
    "Pinyon Script": "Snell Roundhand",
    "Mr De Haviland": "Snell Roundhand",
    "Cookie": "Snell Roundhand",
    "Tangerine": "Snell Roundhand",
    "Yellowtail": "Snell Roundhand",

    // Monospace
    "JetBrains Mono": "Menlo",
    "Fira Code": "Menlo",
    "Source Code Pro": "Menlo",
    "IBM Plex Mono": "Menlo",
    "Roboto Mono": "Menlo",
    "Inconsolata": "Menlo",
    "Space Mono": "Menlo",
    "Ubuntu Mono": "Menlo",
    "Cousine": "Courier New",
    "Anonymous Pro": "Menlo",
    "Overpass Mono": "Menlo",
    "DM Mono": "Menlo",
    "Red Hat Mono": "Menlo",
    "Azeret Mono": "Menlo",
    "Martian Mono": "Menlo",
]

/// iOS system fonts that are natively available
public let iosNativeFonts: Set<String> = [
    "SF Pro", ".AppleSystemUIFont",
    "SF Pro Display",
    "SF Pro Text",
    "SF Pro Rounded",
    "New York",
    "Helvetica Neue", "Helvetica",
    "Georgia",
    "Times New Roman",
    "Menlo",
    "Courier New",
    "Avenir", "Avenir Next",
    "Baskerville",
    "Didot",
    "Futura",
    "Impact",
    "Marker Felt",
    "Snell Roundhand",
    "Bradley Hand",
    "Noteworthy",
    "Rockwell",
    "Apple Garamond",
]

/// Gets the appropriate iOS font for a given font family name
/// Returns the original name if it's a native iOS font, otherwise returns the fallback
public func getIOSFont(for fontFamily: String) -> String {
    // If it's a native iOS font, use it directly
    if iosNativeFonts.contains(fontFamily) {
        return fontFamily
    }

    // Try to find a fallback mapping
    if let fallback = iosFontFallbacks[fontFamily] {
        return fallback
    }

    // Default to system font
    return ".AppleSystemUIFont"
}

/// Creates a SwiftUI Font for the given font family, size, and weight
public func makeFont(family: String?, size: CGFloat, weight: Font.Weight) -> Font {
    guard let family = family, !family.isEmpty else {
        return .system(size: size, weight: weight)
    }

    let mappedFamily = getIOSFont(for: family)

    // For system font, use .system()
    if mappedFamily == ".AppleSystemUIFont" {
        return .system(size: size, weight: weight)
    }

    // For custom/native fonts, use Font.custom
    // Note: Weight is applied via the font name (e.g., "Georgia-Bold") or we fall back
    return Font.custom(mappedFamily, size: size).weight(weight)
}
