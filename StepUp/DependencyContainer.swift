// DependencyContainer.swift - FIXED VERSION

import Foundation

// MARK: - Dependency Container Protocol
protocol DependencyContainer {
    var healthManager: any HealthManagerProtocol { get }
    var networkMonitor: any NetworkMonitorProtocol { get }
    var userRepository: UserRepository { get }
    var stepsRepository: StepsRepository { get }
    var leaderboardRepository: LeaderboardRepository { get }
    var analytics: AnalyticsProtocol { get }
    var logger: LoggerProtocol { get }
}

// MARK: - Extended protocol for concrete access
protocol ConcreteDependencyContainer: DependencyContainer {
    var concreteNetworkMonitor: NetworkMonitor { get }
}

// MARK: - Production Dependency Container
class AppDependencyContainer: ConcreteDependencyContainer {
    // Create concrete instances instead of using protocols directly
    private let _networkMonitor = NetworkMonitor()
    private let _healthManager: HealthManager = {
        // Cast HealthManager.shared to HealthManager to ensure concrete type
        return HealthManager.shared as! HealthManager
    }()
    
    lazy var healthManager: any HealthManagerProtocol = _healthManager
    lazy var networkMonitor: any NetworkMonitorProtocol = _networkMonitor
    lazy var userRepository: UserRepository = SupabaseUserRepository()
    lazy var stepsRepository: StepsRepository = SupabaseStepsRepository()
    lazy var leaderboardRepository: LeaderboardRepository = SupabaseLeaderboardRepository()
    lazy var analytics: AnalyticsProtocol = ConsoleAnalytics()
    lazy var logger: LoggerProtocol = ConsoleLogger()
    
    // Provide access to concrete NetworkMonitor for AppStateManager
    var concreteNetworkMonitor: NetworkMonitor {
        return _networkMonitor
    }
}

// MARK: - Mock Dependency Container (for testing)
class MockDependencyContainer: DependencyContainer {
    var healthManager: any HealthManagerProtocol = MockHealthManager()
    var networkMonitor: any NetworkMonitorProtocol = MockNetworkMonitor()
    var userRepository: UserRepository = MockUserRepository()
    var stepsRepository: StepsRepository = MockStepsRepository()
    var leaderboardRepository: LeaderboardRepository = MockLeaderboardRepository()
    var analytics: AnalyticsProtocol = MockAnalytics()
    var logger: LoggerProtocol = ConsoleLogger()
}

// MARK: - Repository Implementations
class SupabaseUserRepository: UserRepository {
    private let supabase = SupabaseManager.shared.client
    
    func getCurrentUser() async throws -> UserProfile? {
        let session = try await supabase.auth.session
        let profiles: [UserProfile] = try await supabase
            .from("user_profiles")
            .select("id, username, display_name, avatar_url, created_at, updated_at")
            .eq("id", value: session.user.id)
            .execute()
            .value
        
        return profiles.first
    }
    
    func updateUser(_ user: UserProfile) async throws {
        try await supabase
            .from("user_profiles")
            .update([
                "username": user.username,
                "display_name": user.displayName ?? user.username,
                "avatar_url": user.avatarUrl ?? "",
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: user.id)
            .execute()
    }
    
    func createUser(_ user: UserProfileInsert) async throws {
        try await supabase
            .from("user_profiles")
            .insert(user)
            .execute()
    }
    
    func deleteUser(id: UUID) async throws {
        try await supabase
            .from("user_profiles")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

class SupabaseStepsRepository: StepsRepository {
    private let supabase = SupabaseManager.shared.client
    
    func getTodaySteps(for userId: UUID) async throws -> DailySteps? {
        let today = DateFormatter.databaseDate.string(from: Date())
        let steps: [DailySteps] = try await supabase
            .from("daily_steps")
            .select("id, user_id, date, steps, points_earned, points_lost, weekly_average, synced_from")
            .eq("user_id", value: userId)
            .eq("date", value: today)
            .execute()
            .value
        
        return steps.first
    }
    
    func getWeeklySteps(for userId: UUID) async throws -> [DailySteps] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weekAgoString = DateFormatter.databaseDate.string(from: weekAgo)
        
        let steps: [DailySteps] = try await supabase
            .from("daily_steps")
            .select("id, user_id, date, steps, points_earned, points_lost, weekly_average, synced_from")
            .eq("user_id", value: userId)
            .gte("date", value: weekAgoString)
            .order("date", ascending: true)
            .execute()
            .value
        
        return steps
    }
    
    func syncSteps(_ steps: DailyStepsInsert) async throws {
        try await supabase
            .from("daily_steps")
            .upsert(steps, onConflict: "user_id,date")
            .execute()
    }
}

// MARK: - FIXED Leaderboard Repository
class SupabaseLeaderboardRepository: LeaderboardRepository {
    private let supabase = SupabaseManager.shared.client
    
    func getGlobalDaily(limit: Int = 50) async throws -> [LeaderboardEntry] {
        let today = DateFormatter.databaseDate.string(from: Date())
        
        // FIXED: Use the new leaderboard_cache table with proper field mapping
        let cacheResults: [LeaderboardCacheResponse] = try await supabase
            .from("leaderboard_cache")
            .select("user_id, daily_steps, global_daily_rank, user_profiles(username, avatar_url)")
            .eq("date", value: today)
            .order("global_daily_rank", ascending: true)
            .limit(limit)
            .execute()
            .value
        
        return cacheResults.compactMap { result in
            guard let rank = result.globalDailyRank else { return nil }
            
            return LeaderboardEntry(
                id: result.userId,
                username: result.userProfiles?.username ?? "Unknown",
                avatarUrl: result.userProfiles?.avatarUrl,
                steps: result.dailySteps,
                isCurrentUser: false, // Will be set by the caller
                rank: rank
            )
        }
    }
    
    func getFriendsDaily(for userId: UUID) async throws -> [LeaderboardEntry] {
        let today = DateFormatter.databaseDate.string(from: Date())
        
        // Get user's friends
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("friend_id")
            .eq("user_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value
        
        var friendIds = friendships.map { $0.friendId }
        friendIds.append(userId) // Include current user
        
        let cacheResults: [LeaderboardCacheResponse] = try await supabase
            .from("leaderboard_cache")
            .select("user_id, daily_steps, friends_daily_rank, user_profiles(username, avatar_url)")
            .eq("date", value: today)
            .in("user_id", values: friendIds)
            .order("friends_daily_rank", ascending: true)
            .execute()
            .value
        
        return cacheResults.compactMap { result in
            guard let rank = result.friendsDailyRank else { return nil }
            
            return LeaderboardEntry(
                id: result.userId,
                username: result.userProfiles?.username ?? "Unknown",
                avatarUrl: result.userProfiles?.avatarUrl,
                steps: result.dailySteps,
                isCurrentUser: result.userId == userId,
                rank: rank
            )
        }
    }
    
    func getGlobalWeekly(limit: Int = 50) async throws -> [LeaderboardEntry] {
        let today = DateFormatter.databaseDate.string(from: Date())
        
        let cacheResults: [LeaderboardCacheResponse] = try await supabase
            .from("leaderboard_cache")
            .select("user_id, weekly_steps, global_weekly_rank, user_profiles(username, avatar_url)")
            .eq("date", value: today)
            .order("global_weekly_rank", ascending: true)
            .limit(limit)
            .execute()
            .value
        
        return cacheResults.compactMap { result in
            guard let rank = result.globalWeeklyRank else { return nil }
            
            return LeaderboardEntry(
                id: result.userId,
                username: result.userProfiles?.username ?? "Unknown",
                avatarUrl: result.userProfiles?.avatarUrl,
                steps: result.weeklySteps,
                isCurrentUser: false,
                rank: rank
            )
        }
    }
    
    func getFriendsWeekly(for userId: UUID) async throws -> [LeaderboardEntry] {
        let today = DateFormatter.databaseDate.string(from: Date())
        
        // Get user's friends
        let friendships: [Friendship] = try await supabase
            .from("friendships")
            .select("friend_id")
            .eq("user_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value
        
        var friendIds = friendships.map { $0.friendId }
        friendIds.append(userId)
        
        let cacheResults: [LeaderboardCacheResponse] = try await supabase
            .from("leaderboard_cache")
            .select("user_id, weekly_steps, friends_weekly_rank, user_profiles(username, avatar_url)")
            .eq("date", value: today)
            .in("user_id", values: friendIds)
            .order("friends_weekly_rank", ascending: true)
            .execute()
            .value
        
        return cacheResults.compactMap { result in
            guard let rank = result.friendsWeeklyRank else { return nil }
            
            return LeaderboardEntry(
                id: result.userId,
                username: result.userProfiles?.username ?? "Unknown",
                avatarUrl: result.userProfiles?.avatarUrl,
                steps: result.weeklySteps,
                isCurrentUser: result.userId == userId,
                rank: rank
            )
        }
    }
}

// MARK: - Analytics Implementation
class ConsoleAnalytics: AnalyticsProtocol {
    func track(event: String, parameters: [String: Any]?) {
        print("📊 Analytics: \(event) - \(parameters ?? [:])")
    }
    
    func setUserProperty(_ value: String, forName: String) {
        print("👤 User Property: \(forName) = \(value)")
    }
    
    func logError(_ error: Error, additionalInfo: [String: Any]?) {
        print("💥 Analytics Error: \(error) - \(additionalInfo ?? [:])")
    }
}

// MARK: - Logger Implementation
class ConsoleLogger: LoggerProtocol {
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("🔍 DEBUG [\(fileName(file)):\(line)] \(message)")
        #endif
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("ℹ️ INFO [\(fileName(file)):\(line)] \(message)")
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("⚠️ WARNING [\(fileName(file)):\(line)] \(message)")
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        print("❌ ERROR [\(fileName(file)):\(line)] \(message)")
        if let error = error {
            print("   Error details: \(error)")
        }
    }
    
    private func fileName(_ path: String) -> String {
        return String(path.split(separator: "/").last ?? "Unknown")
    }
}

