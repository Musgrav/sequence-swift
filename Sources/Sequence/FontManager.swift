// ============================================
// Dynamic Font Manager
// ============================================
// Handles dynamic loading of Google Fonts at runtime.
// Fonts are downloaded on-demand and cached locally.
// ============================================

import Foundation
import SwiftUI
import CoreText
import UIKit

// Helper class for bundle detection in non-SPM builds
private class BundleToken {}

/// Manages dynamic font loading for the Sequence SDK
public final class FontManager: @unchecked Sendable {
    public static let shared = FontManager()
    
    /// Cache of loaded fonts (font name -> whether it's available)
    private var loadedFonts: [String: Bool] = [:]
    private let loadedFontsLock = NSLock()
    
    /// Fonts currently being downloaded
    private var downloadingFonts: Set<String> = []
    private let downloadingLock = NSLock()
    
    /// Callbacks waiting for font downloads
    private var fontCallbacks: [String: [(Bool) -> Void]] = [:]
    private let callbacksLock = NSLock()
    
    /// Directory for cached fonts
    private var fontCacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fontDir = caches.appendingPathComponent("SequenceFonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: fontDir, withIntermediateDirectories: true)
        return fontDir
    }
    
    private init() {
        // Pre-register any bundled fonts from the SDK
        registerBundledFonts()
    }
    
    // MARK: - Public API
    
    /// Check if a font is available (either system, bundled, or already downloaded)
    public func isFontAvailable(_ fontName: String) -> Bool {
        // Check if it's a system font
        if UIFont(name: fontName, size: 12) != nil {
            return true
        }
        
        // Check without spaces (e.g., "Work Sans" -> "WorkSans")
        let noSpaces = fontName.replacingOccurrences(of: " ", with: "")
        if UIFont(name: noSpaces, size: 12) != nil {
            return true
        }
        
        // Check our cache
        loadedFontsLock.lock()
        let cached = loadedFonts[fontName]
        loadedFontsLock.unlock()
        
        return cached ?? false
    }
    
    /// Get a UIFont, downloading if necessary. Returns nil if font isn't ready yet.
    public func getFont(named fontName: String, size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont? {
        // Try exact name
        if let font = UIFont(name: fontName, size: size) {
            return font
        }
        
        // Try without spaces
        let noSpaces = fontName.replacingOccurrences(of: " ", with: "")
        if let font = UIFont(name: noSpaces, size: size) {
            return font
        }
        
        // Try with weight suffix
        let weightSuffix = weightSuffixFor(weight)
        if let font = UIFont(name: "\(noSpaces)-\(weightSuffix)", size: size) {
            return font
        }
        
        // Font not available yet
        return nil
    }
    
    /// Request a font to be loaded. Calls completion when ready.
    public func loadFont(_ fontName: String, completion: @escaping (Bool) -> Void) {
        // Already available?
        if isFontAvailable(fontName) {
            completion(true)
            return
        }
        
        // Check if cached on disk
        if loadCachedFont(fontName) {
            completion(true)
            return
        }
        
        // Already downloading?
        downloadingLock.lock()
        let isDownloading = downloadingFonts.contains(fontName)
        if !isDownloading {
            downloadingFonts.insert(fontName)
        }
        downloadingLock.unlock()
        
        // Add callback
        callbacksLock.lock()
        if fontCallbacks[fontName] == nil {
            fontCallbacks[fontName] = []
        }
        fontCallbacks[fontName]?.append(completion)
        callbacksLock.unlock()
        
        // Start download if not already in progress
        if !isDownloading {
            downloadFont(fontName)
        }
    }
    
    /// Preload multiple fonts asynchronously
    public func preloadFonts(_ fontNames: [String]) {
        for fontName in fontNames {
            loadFont(fontName) { _ in }
        }
    }
    
    // MARK: - Font Download
    
    private func downloadFont(_ fontName: String) {
        // Convert font name to Google Fonts URL format
        let urlFontName = fontName.replacingOccurrences(of: " ", with: "+")
        let googleFontsURL = "https://fonts.googleapis.com/css2?family=\(urlFontName):wght@400;500;600;700&display=swap"
        
        print("🔤 [FontManager] Downloading font: \(fontName)")
        
        guard let cssURL = URL(string: googleFontsURL) else {
            notifyCallbacks(fontName: fontName, success: false)
            return
        }
        
        // First, fetch the CSS to find the actual font file URLs
        let task = URLSession.shared.dataTask(with: cssURL) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let cssString = String(data: data, encoding: .utf8) else {
                print("⚠️ [FontManager] Failed to fetch CSS for \(fontName)")
                self?.notifyCallbacks(fontName: fontName, success: false)
                return
            }
            
            // Parse the font URLs from the CSS
            self.parseFontURLsAndDownload(cssString: cssString, fontName: fontName)
        }
        task.resume()
    }
    
    private func parseFontURLsAndDownload(cssString: String, fontName: String) {
        // Find font file URLs in the CSS
        // Pattern: url(https://fonts.gstatic.com/...)
        let pattern = #"url\((https://fonts\.gstatic\.com/[^)]+)\)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            notifyCallbacks(fontName: fontName, success: false)
            return
        }
        
        let range = NSRange(cssString.startIndex..., in: cssString)
        let matches = regex.matches(in: cssString, options: [], range: range)
        
        // Get unique font URLs (there may be multiple weights)
        var fontURLs: [URL] = []
        for match in matches {
            if let urlRange = Range(match.range(at: 1), in: cssString) {
                let urlString = String(cssString[urlRange])
                if let url = URL(string: urlString) {
                    fontURLs.append(url)
                }
            }
        }
        
        guard !fontURLs.isEmpty else {
            print("⚠️ [FontManager] No font URLs found in CSS for \(fontName)")
            notifyCallbacks(fontName: fontName, success: false)
            return
        }
        
        // Download the first (regular) font file
        downloadFontFile(from: fontURLs[0], fontName: fontName)
    }
    
    private func downloadFontFile(from url: URL, fontName: String) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data else {
                print("⚠️ [FontManager] Failed to download font file for \(fontName)")
                self?.notifyCallbacks(fontName: fontName, success: false)
                return
            }
            
            // Register the font
            let success = self.registerFontData(data, fontName: fontName)
            
            if success {
                // Cache to disk
                self.cacheFontData(data, fontName: fontName)
                print("✅ [FontManager] Successfully loaded font: \(fontName)")
            } else {
                print("⚠️ [FontManager] Failed to register font: \(fontName)")
            }
            
            self.notifyCallbacks(fontName: fontName, success: success)
        }
        task.resume()
    }
    
    // MARK: - Font Registration
    
    private func registerFontData(_ data: Data, fontName: String) -> Bool {
        guard let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else {
            return false
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)
        
        if success {
            loadedFontsLock.lock()
            loadedFonts[fontName] = true
            loadedFontsLock.unlock()
        }
        
        return success
    }
    
    private func registerBundledFonts() {
        // Register any fonts bundled with the SDK package
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: BundleToken.self)
        #endif
        
        // Look for Fonts directory
        guard let fontsURL = bundle.url(forResource: "Fonts", withExtension: nil) ??
                             bundle.resourceURL?.appendingPathComponent("Fonts") else {
            print("🔤 [FontManager] No bundled fonts directory found")
            return
        }
        
        let fontExtensions = ["ttf", "otf"]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: fontsURL, includingPropertiesForKeys: nil)
            var registeredCount = 0
            
            for fileURL in contents {
                if fontExtensions.contains(fileURL.pathExtension.lowercased()) {
                    if let data = try? Data(contentsOf: fileURL) {
                        let fontName = fileURL.deletingPathExtension().lastPathComponent
                        if registerFontData(data, fontName: fontName) {
                            print("🔤 [FontManager] Registered bundled font: \(fontName)")
                            registeredCount += 1
                        }
                    }
                }
            }
            
            if registeredCount > 0 {
                print("🔤 [FontManager] Registered \(registeredCount) bundled fonts")
            }
        } catch {
            // No bundled fonts - will download on demand
            print("🔤 [FontManager] No bundled fonts found, will download on demand")
        }
    }
    
    // MARK: - Caching
    
    private func cacheFontData(_ data: Data, fontName: String) {
        let safeName = fontName.replacingOccurrences(of: " ", with: "_")
        let cacheURL = fontCacheDirectory.appendingPathComponent("\(safeName).ttf")
        try? data.write(to: cacheURL)
    }
    
    private func loadCachedFont(_ fontName: String) -> Bool {
        let safeName = fontName.replacingOccurrences(of: " ", with: "_")
        let cacheURL = fontCacheDirectory.appendingPathComponent("\(safeName).ttf")
        
        guard let data = try? Data(contentsOf: cacheURL) else {
            return false
        }
        
        return registerFontData(data, fontName: fontName)
    }
    
    // MARK: - Helpers
    
    private func notifyCallbacks(fontName: String, success: Bool) {
        downloadingLock.lock()
        downloadingFonts.remove(fontName)
        downloadingLock.unlock()
        
        callbacksLock.lock()
        let callbacks = fontCallbacks.removeValue(forKey: fontName) ?? []
        callbacksLock.unlock()
        
        DispatchQueue.main.async {
            for callback in callbacks {
                callback(success)
            }
        }
    }
    
    private func weightSuffixFor(_ weight: UIFont.Weight) -> String {
        switch weight {
        case .ultraLight: return "ExtraLight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "SemiBold"
        case .bold: return "Bold"
        case .heavy: return "ExtraBold"
        case .black: return "Black"
        default: return "Regular"
        }
    }
}

// MARK: - SwiftUI Font Extension

extension Font {
    /// Creates a font that will dynamically load from Google Fonts if needed
    static func dynamic(_ name: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let uiWeight = weight.toUIFontWeight()
        
        // Try to get the font
        if let uiFont = FontManager.shared.getFont(named: name, size: size, weight: uiWeight) {
            return Font(uiFont)
        }
        
        // Font not ready yet - trigger download and return system font for now
        FontManager.shared.loadFont(name) { _ in }
        return .system(size: size, weight: weight)
    }
}

extension Font.Weight {
    func toUIFontWeight() -> UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}
