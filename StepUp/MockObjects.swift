// MockObjects.swift - FIXED VERSION

import Foundation
import SwiftUI
import Network

// MARK: - Mock Health Manager
class MockHealthManager: HealthManagerProtocol, ObservableObject {
    @Published var todaySteps: Int = 5000
    @Published var weeklyAverage: Int = 4500
    @Published var isAuthorized: Bool = true
    @Published var isLoading: Bool = false
    @Published var currentTier: Tier? = globalTierList[2] // Daily Stepper
    @Published var userStats: UserStats? = nil
    
    var shouldFailRequests = false
    
    func startTrackingForAuthenticatedUser() {
        print("Mock: Starting health tracking")
    }
    
    func stopTracking() {
        print("Mock: Stopping health tracking")
    }
    
    func fetchInitialData() async {
        if shouldFailRequests {
            return
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            self.todaySteps = Int.random(in: 3000...12000)
            self.weeklyAverage = Int.random(in: 4000...8000)
        }
    }
    
    func fetchTodaySteps() async {
        await fetchInitialData()
    }
    
    func fetchWeeklySteps() async {
        await fetchInitialData()
    }
}

// MARK: - Mock Network Monitor
class MockNetworkMonitor: NetworkMonitorProtocol, ObservableObject {
    @Published var isConnected: Bool = true
    var connectionType: NWInterface.InterfaceType? = .wifi
    
    func startMonitoring() {
        print("Mock: Starting network monitoring")
    }
    
    func stopMonitoring() {
        print("Mock: Stopping network monitoring")
    }
    
    func simulateDisconnection() {
        isConnected = false
        connectionType = nil
    }
    
    func simulateReconnection() {
        isConnected = true
        connectionType = .wifi
    }
}

// MARK: - Mock User Repository
class MockUserRepository: UserRepository {
    var shouldFailRequests = false
    var mockUsers: [UserProfile] = []
    
    func getCurrentUser() async throws -> UserProfile? {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return UserProfile(
            id: UUID(),
            username: "testuser",
            displayName: "Test User",
            avatarUrl: nil,
            timezone: "UTC",  // ADDED: timezone field
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func updateUser(_ user: UserProfile) async throws {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        print("Mock: Updated user \(user.username)")
    }
    
    func createUser(_ user: UserProfileInsert) async throws {
        if shouldFailRequests {
            throw StepUpError.supabaseAuthError("Mock signup failed")
        }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Mock: Created user \(user.username)")
    }
    
    func deleteUser(id: UUID) async throws {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        print("Mock: Deleted user \(id)")
    }
}

// MARK: - Mock Steps Repository
class MockStepsRepository: StepsRepository {
    var shouldFailRequests = false
    private var mockSteps: [DailySteps] = []
    
    func getTodaySteps(for userId: UUID) async throws -> DailySteps? {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        return DailySteps(
            id: UUID(),
            userId: userId,
            date: DateFormatter.databaseDate.string(from: Date()),
            steps: Int.random(in: 3000...10000),
            pointsEarned: Int.random(in: 0...300),
            pointsLost: 0,
            weeklyAverage: Int.random(in: 4000...6000),
            syncedFrom: "mock"
        )
    }
    
    func getWeeklySteps(for userId: UUID) async throws -> [DailySteps] {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        return (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            return DailySteps(
                id: UUID(),
                userId: userId,
                date: DateFormatter.databaseDate.string(from: date),
                steps: Int.random(in: 2000...12000),
                pointsEarned: Int.random(in: 0...400),
                pointsLost: Int.random(in: 0...100),
                weeklyAverage: Int.random(in: 4000...6000),
                syncedFrom: "mock"
            )
        }
    }
    
    func syncSteps(_ steps: DailyStepsInsert) async throws {
        if shouldFailRequests {
            throw StepUpError.backgroundSyncFailed
        }
        
        try await Task.sleep(nanoseconds: 150_000_000)
        print("Mock: Synced \(steps.steps) steps for user \(steps.userId)")
    }
}

// MARK: - Mock Leaderboard Repository
class MockLeaderboardRepository: LeaderboardRepository {
    var shouldFailRequests = false
    
    func getGlobalDaily(limit: Int) async throws -> [LeaderboardEntry] {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return generateMockLeaderboard(count: min(limit, 20))
    }
    
    func getFriendsDaily(for userId: UUID) async throws -> [LeaderboardEntry] {
        if shouldFailRequests {
            throw StepUpError.networkUnavailable
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        var friends = generateMockLeaderboard(count: 5)
        
        // FIXED: Add current user with rank
        friends.append(LeaderboardEntry(
            id: userId,
            username: "You",
            avatarUrl: nil,
            steps: Int.random(in: 5000...8000),
            isCurrentUser: true,
            rank: friends.count + 1 // Add rank
        ))
        
        return friends.sorted { $0.steps > $1.steps }
    }
    
    func getGlobalWeekly(limit: Int) async throws -> [LeaderboardEntry] {
        return try await getGlobalDaily(limit: limit)
    }
    
    func getFriendsWeekly(for userId: UUID) async throws -> [LeaderboardEntry] {
        return try await getFriendsDaily(for: userId)
    }
    
    private func generateMockLeaderboard(count: Int) -> [LeaderboardEntry] {
        let mockUsernames = [
            "sarah_walker", "mike_runner", "emma_steps", "alex_stride",
            "jason_hiker", "lily_power", "maya_fitness", "sam_active",
            "nina_moves", "david_steps", "zoe_runner", "tyler_walk"
        ]
        
        return (0..<count).enumerated().map { index, _ in
            LeaderboardEntry(
                id: UUID(),
                username: mockUsernames[index % mockUsernames.count],
                avatarUrl: nil,
                steps: Int.random(in: 8000...15000),
                isCurrentUser: false,
                rank: index + 1 // FIXED: Add rank
            )
        }.sorted { $0.steps > $1.steps }
    }
}

// MARK: - Mock Analytics
class MockAnalytics: AnalyticsProtocol {
    private var events: [String: [String: Any]] = [:]
    private var userProperties: [String: String] = [:]
    private var errors: [Error] = []
    
    func track(event: String, parameters: [String: Any]?) {
        events[event] = parameters
        print("📊 Mock Analytics: \(event) - \(parameters ?? [:])")
    }
    
    func setUserProperty(_ value: String, forName: String) {
        userProperties[forName] = value
        print("👤 Mock User Property: \(forName) = \(value)")
    }
    
    func logError(_ error: Error, additionalInfo: [String: Any]?) {
        errors.append(error)
        print("💥 Mock Analytics Error: \(error) - \(additionalInfo ?? [:])")
    }
    
    // Test helpers
    func getTrackedEvents() -> [String: [String: Any]] {
        return events
    }
    
    func getUserProperties() -> [String: String] {
        return userProperties
    }
    
    func getLoggedErrors() -> [Error] {
        return errors
    }
    
    func reset() {
        events.removeAll()
        userProperties.removeAll()
        errors.removeAll()
    }
}

// MARK: - Test Data Factory
struct TestDataFactory {
    // FIXED: Added timezone parameter to createMockUser
    static func createMockUser(username: String = "testuser", timezone: String = "UTC") -> UserProfile {
        return UserProfile(
            id: UUID(),
            username: username,
            displayName: "\(username.capitalized) Display",
            avatarUrl: nil,
            timezone: timezone,  // ADDED: timezone field
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static func createMockUserStats(points: Int = 1500) -> UserStats {
        return UserStats(
            id: UUID(),
            userId: UUID(),
            currentTierId: globalTierList.getTier(for: points).id,
            totalPoints: points,
            weeklyAverageSteps: 5000,
            lifetimeSteps: 250000,
            currentStreakDays: 7,
            longestStreakDays: 15,
            lastCalculatedAt: Date()
        )
    }
    
    static func createMockDailySteps(
        steps: Int = 6000,
        date: Date = Date(),
        userId: UUID = UUID()
    ) -> DailySteps {
        return DailySteps(
            id: UUID(),
            userId: userId,
            date: DateFormatter.databaseDate.string(from: date),
            steps: steps,
            pointsEarned: max(0, (steps - 5000) / 500 * 100),
            pointsLost: 0,
            weeklyAverage: 5000,
            syncedFrom: "test"
        )
    }
    
    static func createMockLeaderboardEntry(
        username: String = "testuser",
        steps: Int = 8000,
        isCurrentUser: Bool = false,
        rank: Int = 1 // FIXED: Add rank parameter
    ) -> LeaderboardEntry {
        return LeaderboardEntry(
            id: UUID(),
            username: username,
            avatarUrl: nil,
            steps: steps,
            isCurrentUser: isCurrentUser,
            rank: rank // FIXED: Include rank
        )
    }
}
