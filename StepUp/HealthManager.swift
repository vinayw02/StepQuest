import HealthKit
import SwiftUI
import Foundation

class HealthManager: HealthManagerProtocol, ObservableObject {
    static let shared = HealthManager()
    // Use BackgroundHealthManager as the engine
    private let backgroundManager = BackgroundHealthManager.shared
    
    @Published var todaySteps: Int = 0
    @Published var weeklySteps: [Int] = []
    @Published var weeklyAverage: Int = 0
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var currentTier: Tier?
    @Published var userStats: UserStats?
    
    private init() {
        setupObservation()
    }

    // NEW: Access to BackgroundHealthManager's healthStore
    private var healthStore: HKHealthStore {
        return backgroundManager.healthStore
    }
    
    // MARK: - Sync with BackgroundHealthManager
    
    private func setupObservation() {
        // Mirror all published properties from BackgroundHealthManager
        backgroundManager.$todaySteps
            .receive(on: DispatchQueue.main)
            .assign(to: &$todaySteps)
        
        backgroundManager.$weeklySteps
            .receive(on: DispatchQueue.main)
            .assign(to: &$weeklySteps)
        
        backgroundManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthorized)
        
        backgroundManager.$currentTier
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTier)
        
        backgroundManager.$userStats
            .receive(on: DispatchQueue.main)
            .assign(to: &$userStats)
    }
    
    // MARK: - Public Interface (Delegates to BackgroundHealthManager)
    
    func startTrackingForAuthenticatedUser() {
        backgroundManager.startTrackingForNewUser()
        backgroundManager.scheduleNextBackgroundSync()
    }
    
    func stopTracking() {
        backgroundManager.stopTracking()
    }
    
    func fetchInitialData() async {
        // FIXED: Ensure main thread for @Published property updates
        await MainActor.run {
            isLoading = true
        }
        
        await backgroundManager.refreshDataForUI()
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func fetchTodaySteps() async {
        await backgroundManager.refreshDataForUI()
    }
    
    func fetchWeeklySteps() async {
        await backgroundManager.refreshDataForUI()
    }
    
    func fetchUserStats() async {
        await backgroundManager.refreshDataForUI()
    }
    
    // For backward compatibility with existing code
    func requestAuthorization() {
        startTrackingForAuthenticatedUser()
    }
    
    func syncStepsToDatabase() async {
        await backgroundManager.refreshDataForUI()
    }
    
    // NEW: 7-day catch-up sync function
    func syncLast7Days() async {
        print("🔄 Starting 7-day catch-up sync...")
        
        guard isAuthorized else {
            print("❌ HealthKit not authorized, skipping catch-up sync")
            return
        }
        
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id
            
            // Get the last 7 days of data from HealthKit
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            for daysBack in 0..<7 {
                guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: today) else { continue }
                let dateString = DateFormatter.databaseDate.string(from: targetDate)
                
                // Get steps for this specific day from HealthKit
                let steps = await fetchStepsForSpecificDay(targetDate)
                
                guard steps > 0 else {
                    print("⏭️ Skipping \(dateString): no steps recorded")
                    continue
                }
                
                print("📊 \(dateString): \(steps) steps from HealthKit")
                
                // Create/update database record for this day
                let stepData = DailyStepsInsert(
                    userId: userId,
                    date: dateString,
                    steps: steps,
                    pointsEarned: 0, // Database calculates
                    pointsLost: 0,   // Database calculates
                    weeklyAverage: nil, // Database calculates
                    syncedFrom: "healthkit_catchup"
                )
                
                try await SupabaseManager.shared.client
                    .from("daily_steps")
                    .upsert(stepData, onConflict: "user_id,date")
                    .execute()
                
                print("✅ Updated \(dateString) with \(steps) steps")
            }
            
            print("✅ 7-day catch-up sync completed successfully")
            
        } catch {
            print("❌ 7-day catch-up sync failed: \(error)")
        }
    }

    // NEW: Helper function to get steps for a specific day
    private func fetchStepsForSpecificDay(_ date: Date) async -> Int {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            
            HealthManager.shared.backgroundManager.healthStore.execute(query)
        }
    }
}
