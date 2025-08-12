// InputValidation.swift - CREATE THIS AS A NEW FILE

import Foundation

// MARK: - String Validation Extensions
extension String {
    var isValidUsername: Bool {
        let pattern = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
    
    var isValidPassword: Bool {
        return count >= 8 &&
               contains(where: { $0.isLetter }) &&
               contains(where: { $0.isNumber })
    }
    
    var sanitized: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
    
    var isValidDisplayName: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 30
    }
}

// MARK: - Rate Limiting for Authentication
class AuthRateLimiter {
    static let shared = AuthRateLimiter()
    private var attempts: [String: [Date]] = [:]
    private let maxAttempts = 5
    private let timeWindow: TimeInterval = 300 // 5 minutes
    private let queue = DispatchQueue(label: "auth.ratelimiter", qos: .utility)
    
    private init() {}
    
    func isBlocked(for username: String) -> Bool {
        return queue.sync {
            let now = Date()
            let userAttempts = attempts[username] ?? []
            let recentAttempts = userAttempts.filter { now.timeIntervalSince($0) < timeWindow }
            
            attempts[username] = recentAttempts
            return recentAttempts.count >= maxAttempts
        }
    }
    
    func recordAttempt(for username: String) {
        queue.async { [weak self] in
            let now = Date()
            if self?.attempts[username] == nil {
                self?.attempts[username] = []
            }
            self?.attempts[username]?.append(now)
        }
    }
    
    func clearAttempts(for username: String) {
        queue.async { [weak self] in
            self?.attempts[username] = []
        }
    }
}

// MARK: - Simple Profanity Filter
class ProfanityFilter {
    static let shared = ProfanityFilter()
    
    private let blockedWords = [
        "spam", "test", "admin", "null", "undefined",
        "bot", "fake", "scam", "hack", "cheat"
    ]
    
    private init() {}
    
    func containsProfanity(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return blockedWords.contains { lowercased.contains($0) }
    }
    
    func containsInappropriateContent(_ text: String) -> Bool {
        // Check for common inappropriate patterns
        let lowercased = text.lowercased()
        
        // Check for excessive repeated characters
        let hasExcessiveRepeats = lowercased.range(of: #"(.)\1{4,}"#, options: .regularExpression) != nil
        
        // Check for profanity
        let hasProfanity = containsProfanity(lowercased)
        
        return hasExcessiveRepeats || hasProfanity
    }
}
