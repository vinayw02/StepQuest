import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        guard let url = URL(string: "https://wzykthymvxltfkzlihso.supabase.co") else {
            fatalError("Invalid Supabase URL")
        }
        
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6eWt0aHltdnhsdGZremxpaHNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk2OTg4MTEsImV4cCI6MjA2NTI3NDgxMX0.B9aO7OJ3xoBxsxTWq9ThBDWBIfV72dc0u4ZRRxnz26c"
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }
}

// MARK: - Data Models

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let timezone: String?  // ADDED: timezone field
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case timezone
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom initializer for easy updates
    init(id: UUID, username: String, displayName: String?, avatarUrl: String?, timezone: String?, createdAt: Date?, updatedAt: Date?) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.timezone = timezone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // FIXED: Updated method to include timezone
    func updated(username: String? = nil, displayName: String? = nil, avatarUrl: String? = nil, timezone: String? = nil) -> UserProfile {
        return UserProfile(
            id: self.id,
            username: username ?? self.username,
            displayName: displayName ?? self.displayName,
            avatarUrl: avatarUrl ?? self.avatarUrl,
            timezone: timezone ?? self.timezone,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}

struct UserStats: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let currentTierId: Int?
    let totalPoints: Int
    let weeklyAverageSteps: Int
    let lifetimeSteps: Int
    let currentStreakDays: Int
    let longestStreakDays: Int
    let lastCalculatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case currentTierId = "current_tier_id"
        case totalPoints = "total_points"
        case weeklyAverageSteps = "weekly_average_steps"
        case lifetimeSteps = "lifetime_steps"
        case currentStreakDays = "current_streak_days"
        case longestStreakDays = "longest_streak_days"
        case lastCalculatedAt = "last_calculated_at"
    }
}

// FIXED DailySteps model - Replace in SupabaseManager.swift
struct DailySteps: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let date: String // Using String for date to match Supabase
    let steps: Int
    let pointsEarned: Int
    let pointsLost: Int
    let weeklyAverage: Int  // CHANGED: Removed optional - should be Int, not Int?
    let syncedFrom: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case steps
        case pointsEarned = "points_earned"
        case pointsLost = "points_lost"
        case weeklyAverage = "weekly_average"
        case syncedFrom = "synced_from"
    }
}

struct Event: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let startDate: String
    let endDate: String
    let targetSteps: Int
    let bonusPoints: Int
    let isActive: Bool
    let icon: String?
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case targetSteps = "target_steps"
        case bonusPoints = "bonus_points"
        case isActive = "is_active"
        case icon
        case color
    }
}

struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    let status: String
    let requestedBy: UUID
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case requestedBy = "requested_by"
        case createdAt = "created_at"
    }
}

// MARK: - Insert Models

struct UserProfileInsert: Codable {
    let id: UUID
    let username: String
    let displayName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
    }
}

struct UserStatsInsert: Codable {
    let userId: UUID
    let currentTierId: Int?
    let totalPoints: Int
    let weeklyAverageSteps: Int
    let lifetimeSteps: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case currentTierId = "current_tier_id"
        case totalPoints = "total_points"
        case weeklyAverageSteps = "weekly_average_steps"
        case lifetimeSteps = "lifetime_steps"
    }
}

// FIXED DailyStepsInsert model - Replace in SupabaseManager.swift
struct DailyStepsInsert: Codable {
    let userId: UUID
    let date: String
    let steps: Int
    let pointsEarned: Int
    let pointsLost: Int
    let weeklyAverage: Int?  // CHANGED: Make this optional so we can send nil
    let syncedFrom: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case steps
        case pointsEarned = "points_earned"
        case pointsLost = "points_lost"
        case weeklyAverage = "weekly_average"
        case syncedFrom = "synced_from"
    }
}
