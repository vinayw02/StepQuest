// UseCases.swift - FIXED VERSION

import Foundation

// MARK: - Authentication Use Case
struct AuthenticateUserUseCase {
    private let userRepository: UserRepository
    private let analytics: AnalyticsProtocol
    private let logger: LoggerProtocol
    
    init(
        userRepository: UserRepository,
        analytics: AnalyticsProtocol,
        logger: LoggerProtocol
    ) {
        self.userRepository = userRepository
        self.analytics = analytics
        self.logger = logger
    }
    
    func execute(username: String, password: String, isSignUp: Bool) async throws -> UserProfile {
        logger.info("Starting authentication for username: \(username)", file: #file, function: #function, line: #line)
        
        // Validate inputs
        let sanitizedUsername = username.sanitized
        guard sanitizedUsername.isValidUsername else {
            logger.warning("Invalid username format: \(sanitizedUsername)", file: #file, function: #function, line: #line)
            throw StepUpError.invalidInput("username")
        }
        
        guard password.isValidPassword else {
            logger.warning("Invalid password format", file: #file, function: #function, line: #line)
            throw StepUpError.invalidInput("password")
        }
        
        // Check rate limiting
        guard !AuthRateLimiter.shared.isBlocked(for: sanitizedUsername) else {
            logger.warning("Rate limited authentication attempt for: \(sanitizedUsername)", file: #file, function: #function, line: #line)
            analytics.track(event: "auth_rate_limited", parameters: ["username": sanitizedUsername])
            throw StepUpError.rateLimited
        }
        
        // Check for inappropriate content
        guard !ProfanityFilter.shared.containsInappropriateContent(sanitizedUsername) else {
            logger.warning("Inappropriate username content: \(sanitizedUsername)", file: #file, function: #function, line: #line)
            throw StepUpError.invalidInput("username contains inappropriate content")
        }
        
        do {
            let email = "\(sanitizedUsername)@stepup.app"
            
            if isSignUp {
                // Create new user
                try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
                
                let userProfile = UserProfileInsert(
                    id: UUID(), // This will be set by Supabase
                    username: sanitizedUsername,
                    displayName: sanitizedUsername
                )
                
                try await userRepository.createUser(userProfile)
                analytics.track(event: "user_signup", parameters: ["username": sanitizedUsername])
                
            } else {
                // Sign in existing user
                try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
                analytics.track(event: "user_signin", parameters: ["username": sanitizedUsername])
            }
            
            // Get user profile
            guard let user = try await userRepository.getCurrentUser() else {
                throw StepUpError.dataCorruption
            }
            
            // Clear rate limiting on success
            AuthRateLimiter.shared.clearAttempts(for: sanitizedUsername)
            
            logger.info("Authentication successful for: \(sanitizedUsername)", file: #file, function: #function, line: #line)
            
            // Set user timezone for new asymmetric point system
            let userTimeZone = TimeZone.current.identifier
            do {
                try await SupabaseManager.shared.client.rpc("set_user_timezone", params: [
                    "user_id_param": user.id.uuidString,
                    "tz": userTimeZone
                ]).execute()
                logger.info("Timezone set for user: \(userTimeZone)", file: #file, function: #function, line: #line)
            } catch {
                logger.warning("Failed to set timezone: \(error)", file: #file, function: #function, line: #line)
                // Don't fail auth for timezone issues
            }
            
            return user
            
            
            
        } catch {
            AuthRateLimiter.shared.recordAttempt(for: sanitizedUsername)
            analytics.logError(error, additionalInfo: ["username": sanitizedUsername, "isSignUp": isSignUp])
            logger.error("Authentication failed", error: error, file: #file, function: #function, line: #line)
            throw error
        }
    }
}

// MARK: - Sync Steps Use Case
struct SyncStepsUseCase {
    private let healthManager: any HealthManagerProtocol
    private let stepsRepository: StepsRepository
    private let analytics: AnalyticsProtocol
    private let logger: LoggerProtocol
    
    init(
        healthManager: any HealthManagerProtocol,
        stepsRepository: StepsRepository,
        analytics: AnalyticsProtocol,
        logger: LoggerProtocol
    ) {
        self.healthManager = healthManager
        self.stepsRepository = stepsRepository
        self.analytics = analytics
        self.logger = logger
    }
    
    func execute(for userId: UUID) async throws {
        logger.info("Starting steps sync for user: \(userId)", file: #file, function: #function, line: #line)
        
        let todaySteps = healthManager.todaySteps
        let weeklyAverage = healthManager.weeklyAverage
        
        // Validate step data
        guard todaySteps >= 0 && todaySteps <= 100_000 else {
            logger.warning("Invalid step count: \(todaySteps)", file: #file, function: #function, line: #line)
            throw StepUpError.dataCorruption
        }
        
        let stepData = DailyStepsInsert(
            userId: userId,
            date: DateFormatter.databaseDate.string(from: Date()),
            steps: todaySteps,
            pointsEarned: 0, // Let database calculate this
            pointsLost: 0,   // Let database calculate this
            weeklyAverage: weeklyAverage,
            syncedFrom: "healthkit_usecase"
        )
        
        do {
            try await stepsRepository.syncSteps(stepData)
            
            analytics.track(event: "steps_synced", parameters: [
                "steps": todaySteps,
                "weekly_average": weeklyAverage,
                "user_id": userId.uuidString
            ])
            
            logger.info("Steps sync successful: \(todaySteps) steps", file: #file, function: #function, line: #line)
            
        } catch {
            analytics.logError(error, additionalInfo: ["user_id": userId.uuidString, "steps": todaySteps])
            logger.error("Steps sync failed", error: error, file: #file, function: #function, line: #line)
            throw error
        }
    }
}

// MARK: - Load Leaderboard Use Case
struct LoadLeaderboardUseCase {
    private let leaderboardRepository: LeaderboardRepository
    private let analytics: AnalyticsProtocol
    private let logger: LoggerProtocol
    
    init(
        leaderboardRepository: LeaderboardRepository,
        analytics: AnalyticsProtocol,
        logger: LoggerProtocol
    ) {
        self.leaderboardRepository = leaderboardRepository
        self.analytics = analytics
        self.logger = logger
    }
    
    func execute(type: LeaderboardType, period: LeaderboardPeriod, userId: UUID) async throws -> [LeaderboardEntry] {
        logger.info("Loading leaderboard: \(type) - \(period)", file: #file, function: #function, line: #line)
        
        do {
            var entries: [LeaderboardEntry]
            
            switch (type, period) {
            case (.global, .daily):
                entries = try await leaderboardRepository.getGlobalDaily(limit: 50)
            case (.global, .weekly):
                entries = try await leaderboardRepository.getGlobalWeekly(limit: 50)
            case (.friends, .daily):
                entries = try await leaderboardRepository.getFriendsDaily(for: userId)
            case (.friends, .weekly):
                entries = try await leaderboardRepository.getFriendsWeekly(for: userId)
            }
            
            // FIXED: Mark current user - preserve existing rank
            entries = entries.map { entry in
                LeaderboardEntry(
                    id: entry.id,
                    username: entry.username,
                    avatarUrl: entry.avatarUrl,
                    steps: entry.steps,
                    isCurrentUser: entry.id == userId,
                    rank: entry.rank // FIXED: Keep the existing rank
                )
            }
            
            analytics.track(event: "leaderboard_loaded", parameters: [
                "type": type.rawValue,
                "period": period.rawValue,
                "count": entries.count
            ])
            
            logger.info("Leaderboard loaded successfully: \(entries.count) entries", file: #file, function: #function, line: #line)
            return entries
            
        } catch {
            analytics.logError(error, additionalInfo: [
                "type": type.rawValue,
                "period": period.rawValue,
                "user_id": userId.uuidString
            ])
            logger.error("Leaderboard loading failed", error: error, file: #file, function: #function, line: #line)
            throw error
        }
    }
}

// MARK: - Points Calculator
struct PointsCalculator {
    static func calculatePoints(currentSteps: Int, weeklyAverage: Int) -> (pointsEarned: Int, pointsLost: Int) {
        let difference = currentSteps - weeklyAverage
        
        if difference >= 500 {
            // Bonus points for exceeding average
            let bonusSteps = difference
            let pointsEarned = min((bonusSteps / 500) * 100, 1000) // Cap at 1000 points
            return (pointsEarned, 0)
        } else if difference <= -500 {
            // Penalty for falling short
            let missedSteps = abs(difference)
            let pointsLost = min((missedSteps / 500) * 50, 500) // Cap at 500 points penalty
            return (0, pointsLost)
        } else {
            // Within 500 steps of average - no change
            return (0, 0)
        }
    }
}

// MARK: - Supporting Types
enum LeaderboardType: String, CaseIterable {
    case global = "global"
    case friends = "friends"
}

enum LeaderboardPeriod: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
}
