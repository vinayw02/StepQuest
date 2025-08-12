import HealthKit
import SwiftUI
import Foundation
import BackgroundTasks

class BackgroundHealthManager: ObservableObject {
    static let shared = BackgroundHealthManager()
    
    let healthStore = HKHealthStore()  // CHANGED: Removed private
    private let supabase = SupabaseManager.shared.client
    
    @Published var todaySteps: Int = 0
    @Published var weeklySteps: [Int] = []
    @Published var weeklyAverage: Int = 0
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var currentTier: Tier?
    @Published var userStats: UserStats?
    @Published var lastError: StepUpError?
    @Published var isOfflineMode = false
    
    // Background task identifier
    static let backgroundTaskIdentifier = "com.stepup.background-health-sync"
    
    // Tracking control
    private var isTrackingActive = false
    private var lastSyncSteps: Int = 0
    private var lastSyncDate: Date?
    private var isSyncing = false
    private var dataCache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "health.cache", qos: .utility)
    private var retryAttempts = 0
    
    private init() {
        // REMOVED: setupBackgroundTasks() - now handled in AppDelegate
    }
    
    // MARK: - Public Control Methods
    
    func startTrackingForNewUser() {
        // Only start tracking for authenticated users
        guard !isTrackingActive else { return }
        
        isTrackingActive = true
        requestHealthKitPermission()
    }
    
    func stopTracking() {
        isTrackingActive = false
        // Clean up any observers if needed
    }
    
    // MARK: - Background Task Setup (MOVED TO PUBLIC)
    
    func scheduleNextBackgroundSync() {
        guard isTrackingActive else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // Every 1 hour

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background sync scheduled for 1 hour from now")
        } catch {
            print("❌ Failed to schedule background sync: \(error)")
        }
    }
    
    // MARK: - HealthKit Setup
    
    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        healthStore.requestAuthorization(toShare: nil, read: [stepType]) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.setupHealthKitObserver()
                    self?.scheduleNextBackgroundSync()
                    Task {
                        await self?.performInitialDataLoad()
                    }
                }
            }
        }
    }
    
    private func setupHealthKitObserver() {
        guard isTrackingActive else { return }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, _ in
            guard let self = self, self.isTrackingActive else { return }
            
            // Only sync if we haven't synced recently
            let now = Date()
            if let lastSync = self.lastSyncDate,
               now.timeIntervalSince(lastSync) < 300 { // 5 minutes minimum
                return
            }
            
            Task {
                await self.performQuickSync()
            }
        }
        
        healthStore.execute(query)
        
        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in
            // Silent - no logging
        }
    }
    
    // MARK: - Data Sync Methods
    
    private func performInitialDataLoad() async {
        guard isTrackingActive && !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        await fetchTodaySteps()
        await calculateWeeklyAverage()
        await syncToDatabase()
        await loadUserStats()
    }
    
    // MADE PUBLIC: So AppDelegate can call it
    func performBackgroundDataSync() async {
        print("🔄 BackgroundHealthManager: Starting background data sync...")
        
        guard isTrackingActive else {
            print("❌ Background sync skipped: tracking not active")
            return
        }
        
        // Verify user is still authenticated
        do {
            let _ = try await supabase.auth.session
            print("✅ User still authenticated, proceeding with sync")
            await performInitialDataLoad()
            print("✅ Background data sync completed successfully")
        } catch {
            print("❌ User logged out during background sync - stopping tracking")
            // User logged out - stop tracking
            isTrackingActive = false
        }
    }
    
    private func performQuickSync() async {
        guard isTrackingActive && !isSyncing else { return }
        
        // Check cache first to avoid unnecessary API calls
        let cacheKey = "todaySteps_\(Date().formatted(.dateTime.day().month().year()))"
        
        if let cachedSteps = getCachedValue(for: cacheKey) as? Int,
           let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 300 {
            await MainActor.run {
                self.todaySteps = cachedSteps
            }
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        await fetchTodaySteps()
        
        // Cache the result
        setCachedValue(todaySteps, for: cacheKey)
        
        if abs(todaySteps - lastSyncSteps) >= 300 {
            await syncToDatabase()
            lastSyncSteps = todaySteps
            lastSyncDate = Date()
        }
    }
    
    // MARK: - HealthKit Data Fetching (Silent)
    
    private func fetchTodaySteps() async {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = HKQuery.predicateForSamples(withStart: today, end: tomorrow, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [weak self] _, result, _ in
                let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                DispatchQueue.main.async {
                    self?.todaySteps = steps
                }
                continuation.resume()
            }
            healthStore.execute(query)
        }
    }
    
    private func calculateWeeklyAverage() async {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        
        // Last 7 days excluding today
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: yesterday)!
        
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: yesterday, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: weekAgo,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { [weak self] _, results, _ in
                var dailySteps: [Int] = []
                
                if let results = results {
                    results.enumerateStatistics(from: weekAgo, to: yesterday) { statistics, _ in
                        let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                        dailySteps.append(steps)
                    }
                }
                
                DispatchQueue.main.async {
                    self?.weeklySteps = dailySteps
                    self?.weeklyAverage = dailySteps.isEmpty ? 0 : dailySteps.reduce(0, +) / dailySteps.count
                }
                continuation.resume()
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Database Operations (FIXED - No Weekly Average Override)
    
    private func syncToDatabase() async {
        do {
            let session = try await supabase.auth.session
            let today = DateFormatter.databaseDate.string(from: Date())
            
            // Validate data before syncing
            let validatedSteps = validateStepsData(todaySteps)
            
            print("🔄 BackgroundHealthManager syncing \(validatedSteps) steps for \(today)")
            
            // FIXED: Don't send weekly_average - let database calculate it
            let stepData = DailyStepsInsert(
                userId: session.user.id,
                date: today,
                steps: validatedSteps,
                pointsEarned: 0, // Database calculates
                pointsLost: 0,   // Database calculates
                weeklyAverage: nil, // FIXED: Don't override database calculation
                syncedFrom: "healthkit_background"
            )
            
            try await supabase
                .from("daily_steps")
                .upsert(stepData, onConflict: "user_id,date")
                .execute()
            
            print("✅ BackgroundHealthManager sync successful!")
            
            // Success - clear error state
            await MainActor.run {
                self.lastError = nil
                self.isOfflineMode = false
                self.retryAttempts = 0
            }
            
        } catch {
            print("❌ BackgroundHealthManager sync failed: \(error)")
            
            await MainActor.run {
                if error.localizedDescription.contains("network") ||
                   error.localizedDescription.contains("connection") {
                    self.lastError = .networkUnavailable
                    self.isOfflineMode = true
                } else if error.localizedDescription.contains("auth") {
                    self.lastError = .supabaseAuthError(error.localizedDescription)
                } else {
                    self.lastError = .backgroundSyncFailed
                }
            }
            
            // Implement exponential backoff for retries
            if retryAttempts < 5 {
                await scheduleRetryWithBackoff()
            }
        }
    }

    private func validateStepsData(_ steps: Int) -> Int {
        let maxDailySteps = 100_000
        let minDailySteps = 0
        
        guard steps >= minDailySteps && steps <= maxDailySteps else {
            print("⚠️ Invalid steps data detected: \(steps), clamping to valid range")
            return min(max(steps, minDailySteps), maxDailySteps)
        }
        
        return steps
    }

    private func scheduleRetryWithBackoff() async {
        let retryDelay = min(60.0 * pow(2.0, Double(retryAttempts)), 300.0) // Max 5 minutes
        
        print("🔄 Scheduling retry attempt \(retryAttempts + 1) in \(retryDelay) seconds")
        
        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
        
        if retryAttempts < 5 {
            retryAttempts += 1
            await syncToDatabase()
        }
    }
    
    private func loadUserStats() async {
        do {
            let session = try await supabase.auth.session
            
            let stats: [UserStats] = try await supabase
                .from("user_stats")
                .select("*")
                .eq("user_id", value: session.user.id)
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.userStats = stats.first
                
                if let tierId = stats.first?.currentTierId {
                    self.currentTier = globalTierList.first { $0.id == tierId }
                }
            }
            
        } catch {
            // Silent error handling
        }
    }
    
    private func getCachedValue(for key: String) -> Any? {
        return cacheQueue.sync { dataCache[key] }
    }

    private func setCachedValue(_ value: Any, for key: String) {
        cacheQueue.async { [weak self] in
            self?.dataCache[key] = value
        }
    }
    
    // MARK: - Public Interface
    
    func refreshDataForUI() async {
        guard isTrackingActive else { return }
        await performInitialDataLoad()
    }
}
