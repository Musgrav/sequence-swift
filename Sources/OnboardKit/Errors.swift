// Sequence Errors

import Foundation

public enum SequenceError: Error, LocalizedError {
    case notConfigured
    case invalidCredentials
    case networkError(String)
    case decodingError(String)
    case screenNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sequence is not configured. Call Sequence.shared.configure(appId:apiKey:) first."
        case .invalidCredentials:
            return "Invalid API key or App ID. Check your credentials in the Sequence dashboard."
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .screenNotFound(let id):
            return "Screen not found: \(id)"
        }
    }
}

