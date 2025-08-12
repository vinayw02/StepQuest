// GroupsDataModels.swift - FIXED VERSION WITH PROPER IDENTIFIABLE CONFORMANCE

import Foundation

// MARK: - Group Models

struct Group: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let createdBy: UUID
    let leaderboardResetPeriod: LeaderboardResetPeriod
    let inviteCode: String
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdBy = "created_by"
        case leaderboardResetPeriod = "leaderboard_reset_period"
        case inviteCode = "invite_code"
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GroupMembership: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let role: GroupRole
    let joinedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

struct GroupLeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let username: String
    let avatarUrl: String?
    let totalSteps: Int
    let rank: Int
    let isCurrentUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case totalSteps = "total_steps"
        case rank
        case isCurrentUser = "is_current_user"
    }
    
    // Custom implementation for Identifiable
    init(id: UUID, userId: UUID, username: String, avatarUrl: String?, totalSteps: Int, rank: Int, isCurrentUser: Bool) {
        self.id = id
        self.userId = userId
        self.username = username
        self.avatarUrl = avatarUrl
        self.totalSteps = totalSteps
        self.rank = rank
        self.isCurrentUser = isCurrentUser
    }
    
    // Custom decoder to handle the ID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.id = self.userId // Use userId as the ID for Identifiable
        self.username = try container.decode(String.self, forKey: .username)
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.totalSteps = try container.decode(Int.self, forKey: .totalSteps)
        self.rank = try container.decode(Int.self, forKey: .rank)
        self.isCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isCurrentUser) ?? false
    }
}

struct GroupWithMembership: Codable, Identifiable {
    let group: Group
    let membership: GroupMembership
    let currentUserRank: Int?
    
    var id: UUID { group.id }
}

// MARK: - FIXED: GroupWithDetails with Proper Identifiable Conformance

struct GroupWithDetails: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let createdBy: UUID
    let leaderboardResetPeriod: LeaderboardResetPeriod
    let inviteCode: String
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date?
    let updatedAt: Date?
    let userRole: GroupRole
    let userRank: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdBy = "created_by"
        case leaderboardResetPeriod = "leaderboard_reset_period"
        case inviteCode = "invite_code"
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userRole = "user_role"
        case userRank = "user_rank"
    }
}

// MARK: - Enums

enum LeaderboardResetPeriod: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Bi-weekly"
        case .monthly:
            return "Monthly"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Bi-weekly"
        case .monthly:
            return "Monthly"
        }
    }
    
    // FIXED: Added icon extension
    var icon: String {
        switch self {
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.badge.clock"
        case .biweekly:
            return "calendar.badge.plus"
        case .monthly:
            return "calendar.circle.fill"
        }
    }
}

enum GroupRole: String, Codable {
    case admin = "admin"
    case member = "member"
    
    var displayName: String {
        switch self {
        case .admin:
            return "Admin"
        case .member:
            return "Member"
        }
    }
}

// MARK: - Insert Models

struct GroupInsert: Codable {
    let name: String
    let description: String?
    let createdBy: UUID
    let leaderboardResetPeriod: LeaderboardResetPeriod
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case createdBy = "created_by"
        case leaderboardResetPeriod = "leaderboard_reset_period"
    }
}

struct GroupMembershipInsert: Codable {
    let groupId: UUID
    let userId: UUID
    let role: GroupRole
    
    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case userId = "user_id"
        case role
    }
}

// MARK: - Response Models (for database queries)

struct GroupLeaderboardResponse: Codable {
    let userId: UUID
    let username: String
    let avatarUrl: String?
    let totalSteps: Int
    let rank: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case totalSteps = "total_steps"
        case rank
    }
}

// MARK: - Helper Extensions

extension Group {
    var resetPeriodDisplayText: String {
        leaderboardResetPeriod.displayName
    }
    
    var isUserCreator: Bool {
        // This would need to be checked against current user ID
        // Implementation would be in the view model
        return false
    }
}
