// RecapManager.swift - CLEAN & PRISTINE DESIGN

import SwiftUI

// MARK: - Recap Data Models (unchanged)

struct DailyRecap {
    let date: Date
    let steps: Int
    let pointsEarned: Int
    let pointsLost: Int
    let weeklyAverage: Int
}

struct WeeklyRecap {
    let weekStart: Date
    let weekEnd: Date
    let totalSteps: Int
    let totalPointsEarned: Int
    let totalPointsLost: Int
    let daysTracked: Int
}

// MARK: - Recap Manager (unchanged)

@MainActor
class RecapManager: ObservableObject {
    @Published var shouldShowRecap = false
    @Published var dailyRecap: DailyRecap?
    @Published var weeklyRecap: WeeklyRecap?
    @Published var currentPage = 0
    @Published var isLoading = false
    
    private let supabase = SupabaseManager.shared.client
    
    func checkForRecapOnAppOpen() {
        print("🔍 Recap check started...")
        loadRecapData()
    }
    
    func markRecapAsShown() {
        UserDefaults.standard.set(Date(), forKey: "lastRecapShown")
        shouldShowRecap = false
        currentPage = 0
        print("✅ Recap marked as shown")
    }
    
    private func loadRecapData() {
        isLoading = true
        print("🔄 Loading recap data...")
        
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                print("✅ Got user session: \(userId)")
                
                await loadDailyRecap(userId: userId)
                await loadWeeklyRecap(userId: userId)
                
                await MainActor.run {
                    if dailyRecap != nil {
                        print("✅ Showing recap with daily data")
                        shouldShowRecap = true
                    } else {
                        print("❌ No daily recap data found")
                    }
                    isLoading = false
                }
                
            } catch {
                print("❌ Error in loadRecapData: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func loadDailyRecap(userId: UUID) async {
        // Get yesterday's date specifically
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayString = DateFormatter.databaseDate.string(from: yesterday)
        
        print("🔍 Loading recap for YESTERDAY specifically: \(yesterdayString)")
        print("🔍 Today is: \(DateFormatter.databaseDate.string(from: Date()))")
        
        do {
            // First, let's see what recent data exists for this user
            let recentSteps: [DailySteps] = try await supabase
                .from("daily_steps")
                .select("id, user_id, date, steps, points_earned, points_lost, weekly_average, synced_from")
                .eq("user_id", value: userId)
                .order("date", ascending: false)
                .limit(7)
                .execute()
                .value
            
            print("🔍 Found \(recentSteps.count) recent records for user:")
            for step in recentSteps {
                print("   📅 \(step.date): \(step.steps) steps, +\(step.pointsEarned) points, -\(step.pointsLost) points")
            }
            
            // Now look specifically for yesterday's data
            let yesterdaySteps: [DailySteps] = try await supabase
                .from("daily_steps")
                .select("id, user_id, date, steps, points_earned, points_lost, weekly_average, synced_from")
                .eq("user_id", value: userId)
                .eq("date", value: yesterdayString)
                .execute()
                .value
            
            print("🔍 Yesterday (\(yesterdayString)) specific query found \(yesterdaySteps.count) records")
            
            if let stepData = yesterdaySteps.first {
                print("✅ Yesterday's data: \(stepData.steps) steps, +\(stepData.pointsEarned) earned, -\(stepData.pointsLost) lost")
                
                dailyRecap = DailyRecap(
                    date: yesterday,
                    steps: stepData.steps,
                    pointsEarned: stepData.pointsEarned,
                    pointsLost: stepData.pointsLost,
                    weeklyAverage: stepData.weeklyAverage ?? 0
                )
            } else {
                print("❌ No data found for yesterday (\(yesterdayString))")
                // Use most recent data as fallback but keep yesterday's date
                if let mostRecent = recentSteps.first {
                    print("🔄 Using most recent data from \(mostRecent.date) as fallback")
                    dailyRecap = DailyRecap(
                        date: yesterday, // Still show as "yesterday" even if using different data
                        steps: mostRecent.steps,
                        pointsEarned: mostRecent.pointsEarned,
                        pointsLost: mostRecent.pointsLost,
                        weeklyAverage: mostRecent.weeklyAverage ?? 0
                    )
                }
            }
            
        } catch {
            print("❌ Error loading daily recap: \(error)")
        }
    }
    
    private func loadWeeklyRecap(userId: UUID) async {
        let calendar = Calendar.current
        let today = Date()
        
        // Get previous 7 days (excluding today)
        // So if today is June 27, we want June 20-26 (7 days)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let startString = DateFormatter.databaseDate.string(from: sevenDaysAgo)
        let endString = DateFormatter.databaseDate.string(from: yesterday)
        
        print("🔍 Loading weekly recap for previous 7 days: \(startString) to \(endString)")
        
        do {
            let weekSteps: [DailySteps] = try await supabase
                .from("daily_steps")
                .select("id, user_id, date, steps, points_earned, points_lost, weekly_average, synced_from")
                .eq("user_id", value: userId)
                .gte("date", value: startString)
                .lte("date", value: endString)
                .execute()
                .value
            
            print("🔍 Found \(weekSteps.count) days of data for weekly recap")
            for step in weekSteps {
                print("   📅 \(step.date): \(step.steps) steps, +\(step.pointsEarned) earned, -\(step.pointsLost) lost")
            }
            
            if !weekSteps.isEmpty {
                // Simple math - just add up the data from the database
                let totalSteps = weekSteps.reduce(0) { $0 + $1.steps }
                let sevenDayAverage = totalSteps / 7 // Always divide by 7, not by days found
                
                // FIXED: Calculate net points properly
                var netPoints = 0
                for dayData in weekSteps {
                    netPoints += dayData.pointsEarned  // Add points earned
                    netPoints -= dayData.pointsLost    // Subtract points lost
                }
                
                let totalPointsEarned = weekSteps.reduce(0) { $0 + $1.pointsEarned }
                let totalPointsLost = weekSteps.reduce(0) { $0 + $1.pointsLost }
                
                print("✅ Weekly recap calculated:")
                print("   Total steps: \(totalSteps)")
                print("   Points earned: \(totalPointsEarned)")
                print("   Points lost: \(totalPointsLost)")
                print("   Net points: \(netPoints) (should equal \(totalPointsEarned - totalPointsLost))")
                print("   7-day average: \(sevenDayAverage)")
                
                weeklyRecap = WeeklyRecap(
                    weekStart: sevenDaysAgo,
                    weekEnd: yesterday,
                    totalSteps: totalSteps,
                    totalPointsEarned: netPoints, // FIXED: Store net points here
                    totalPointsLost: 0, // Not using this field anymore
                    daysTracked: sevenDayAverage // Using this field for 7-day average
                )
            }
            
        } catch {
            print("❌ Error loading weekly recap: \(error)")
        }
    }
}

// MARK: - CLEAN RECAP OVERLAY

struct RecapOverlayView: View {
    @ObservedObject var recapManager: RecapManager
    
    private var totalPages: Int {
        var count = 0
        if recapManager.dailyRecap != nil { count += 1 }
        if recapManager.weeklyRecap != nil { count += 1 }
        return count
    }
    
    var body: some View {
        ZStack {
            // Simple dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    recapManager.markRecapAsShown()
                }
            
            VStack(spacing: 20) {
                // Clean white card
                VStack(spacing: 0) {
                    TabView(selection: $recapManager.currentPage) {
                        if let dailyRecap = recapManager.dailyRecap {
                            CleanDailyRecapCard(recap: dailyRecap, recapManager: recapManager)
                                .tag(0)
                        }
                        
                        if let weeklyRecap = recapManager.weeklyRecap {
                            CleanWeeklyRecapCard(recap: weeklyRecap, recapManager: recapManager)
                                .tag(1)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                .frame(height: 420)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 24)
                
                // Simple page dots
                if totalPages > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(recapManager.currentPage == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: recapManager.currentPage)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CLEAN DAILY RECAP CARD

struct CleanDailyRecapCard: View {
    let recap: DailyRecap
    let recapManager: RecapManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Proper top spacing
            Spacer().frame(height: 8)
            
            // Header
            VStack(spacing: 8) {
                Text("Yesterday's Recap")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(DateFormatter.recapDisplay.string(from: recap.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Main steps number
            VStack(spacing: 8) {
                Text("\(formatNumber(recap.steps))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                
                Text("steps")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Points section
            if recap.pointsEarned > 0 || recap.pointsLost > 0 {
                HStack(spacing: 40) {
                    if recap.pointsEarned > 0 {
                        VStack(spacing: 4) {
                            Text("+\(recap.pointsEarned)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                            Text("earned")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if recap.pointsLost > 0 {
                        VStack(spacing: 4) {
                            Text("-\(recap.pointsLost)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Text("lost")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Text("0")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text("no change")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Comparison to average
            let difference = recap.steps - recap.weeklyAverage
            if recap.weeklyAverage > 0 {
                HStack(spacing: 8) {
                    Image(systemName: difference >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(difference >= 0 ? Color(red: 0.2, green: 0.7, blue: 0.9) : .red)
                    
                    Text("\(abs(difference)) \(difference >= 0 ? "above" : "below") average")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                recapManager.markRecapAsShown()
            }) {
                Text("Continue")
                    .foregroundColor(.white)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.9))
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }) {
                // Action handled above
            }
            
            // Bottom spacing
            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 32)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - CLEAN WEEKLY RECAP CARD

struct CleanWeeklyRecapCard: View {
    let recap: WeeklyRecap
    let recapManager: RecapManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Proper top spacing
            Spacer().frame(height: 8)
            
            // Header
            VStack(spacing: 8) {
                Text("Previous 7 Day Summary")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(DateFormatter.dateRange.string(from: recap.weekStart)) - \(DateFormatter.dateRange.string(from: recap.weekEnd))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Main steps number
            VStack(spacing: 8) {
                Text(formatLargeNumber(recap.totalSteps))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                
                Text("total steps")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Stats grid
            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    CleanStatItem(
                        value: formatNumber(recap.daysTracked), // This is now weekly average
                        label: "daily avg"
                    )
                    
                    CleanStatItem(
                        value: "\(recap.totalPointsEarned > 0 ? "+" : "")\(recap.totalPointsEarned)",
                        label: "net points"
                    )
                }
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                recapManager.markRecapAsShown()
            }) {
                Text("Continue")
                    .foregroundColor(.white)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.9))
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }) {
                // Action handled above
            }
            
            // Bottom spacing
            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 32)
    }
    
    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 10000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return formatNumber(number)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - CLEAN STAT ITEM

struct CleanStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Date Formatters (unchanged)

extension DateFormatter {
    
    static let recapDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static let dateRange: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static let weekRange: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d - d"
        return formatter
    }()
}
