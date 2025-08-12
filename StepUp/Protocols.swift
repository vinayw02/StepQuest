// Protocols.swift - CREATE THIS AS A NEW FILE

import Foundation
import SwiftUI
import Network  // ADD THIS LINE

// MARK: - Health Manager Protocol
protocol HealthManagerProtocol: ObservableObject {
    var todaySteps: Int { get }
    var weeklyAverage: Int { get }
    var isAuthorized: Bool { get }
    var isLoading: Bool { get }
    var currentTier: Tier? { get }
    var userStats: UserStats? { get }
    
    func startTrackingForAuthenticatedUser()
    func stopTracking()
    func fetchInitialData() async
    func fetchTodaySteps() async
    func fetchWeeklySteps() async
}

// MARK: - Supabase Manager Protocol
protocol SupabaseManagerProtocol {
    func authenticate(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() async throws
    func getCurrentUser() async throws -> UserProfile?
    func syncSteps(_ steps: DailyStepsInsert) async throws
    func fetchUserStats(for userId: UUID) async throws -> UserStats?
}

// MARK: - Network Monitor Protocol
protocol NetworkMonitorProtocol: ObservableObject {
    var isConnected: Bool { get }
    var connectionType: NWInterface.InterfaceType? { get }
    
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - Repository Protocols
protocol UserRepository {
    func getCurrentUser() async throws -> UserProfile?
    func updateUser(_ user: UserProfile) async throws
    func createUser(_ user: UserProfileInsert) async throws
    func deleteUser(id: UUID) async throws
}

protocol StepsRepository {
    func getTodaySteps(for userId: UUID) async throws -> DailySteps?
    func getWeeklySteps(for userId: UUID) async throws -> [DailySteps]
    func syncSteps(_ steps: DailyStepsInsert) async throws
}

protocol LeaderboardRepository {
    func getGlobalDaily(limit: Int) async throws -> [LeaderboardEntry]
    func getFriendsDaily(for userId: UUID) async throws -> [LeaderboardEntry]
    func getGlobalWeekly(limit: Int) async throws -> [LeaderboardEntry]
    func getFriendsWeekly(for userId: UUID) async throws -> [LeaderboardEntry]
}

// MARK: - Analytics Protocol
protocol AnalyticsProtocol {
    func track(event: String, parameters: [String: Any]?)
    func setUserProperty(_ value: String, forName: String)
    func logError(_ error: Error, additionalInfo: [String: Any]?)
}

// MARK: - Logger Protocol
protocol LoggerProtocol {
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, error: Error?, file: String, function: String, line: Int)
}
