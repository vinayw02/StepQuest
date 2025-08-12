// StepUpError.swift - CREATE THIS AS A NEW FILE

import Foundation

enum StepUpError: LocalizedError {
    case networkUnavailable
    case healthKitPermissionDenied
    case supabaseAuthError(String)
    case dataCorruption
    case backgroundSyncFailed
    case rateLimited
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .healthKitPermissionDenied:
            return "HealthKit permission is required to track your steps. Please enable it in Settings."
        case .supabaseAuthError(let message):
            return "Authentication failed: \(message)"
        case .dataCorruption:
            return "Data sync error. Your progress is safe and will be restored."
        case .backgroundSyncFailed:
            return "Background sync failed. Your data will sync when you open the app."
        case .rateLimited:
            return "Too many attempts. Please try again later."
        case .invalidInput(let field):
            return "Invalid \(field). Please check your input."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .healthKitPermissionDenied:
            return "Go to Settings > Privacy & Security > Health > StepQuest and enable all permissions."
        case .supabaseAuthError:
            return "Try signing out and back in."
        case .dataCorruption, .backgroundSyncFailed:
            return "Pull down to refresh or restart the app."
        case .rateLimited:
            return "Wait a few minutes before trying again."
        case .invalidInput:
            return "Please correct the highlighted fields."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .backgroundSyncFailed, .dataCorruption:
            return true
        case .healthKitPermissionDenied, .supabaseAuthError, .rateLimited, .invalidInput:
            return false
        }
    }
}
