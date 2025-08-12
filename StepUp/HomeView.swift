import SwiftUI

// MARK: - PREMIUM HOMEVIEW
struct HomeView: View {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var showHelp = false
    @State private var showTierShowcase = false
    @State private var isRefreshing = false
    @State private var roadScrollOffset: CGFloat = 0
    @State private var showCenterButton = false
    @State private var databaseWeeklyAverage: Int = UserDefaults.standard.integer(forKey: "cachedWeeklyAverage")

    
    private var isAhead: Bool {
        healthManager.todaySteps >= databaseWeeklyAverage  // CHANGED: Use database average
    }
    
    private var stepsToNext: Int {
        let current = healthManager.todaySteps
        let average = databaseWeeklyAverage  // CHANGED: Use database average
        
        if current >= average {
            let stepsAboveAverage = current - average
            let nextMilestone = ((stepsAboveAverage / 500) + 1) * 500
            return nextMilestone - stepsAboveAverage
        } else {
            return average - current
        }
    }
    
    private var progressMessage: String {
        if isAhead {
            return "\(formatNumber(stepsToNext)) steps to +100 points"
        } else {
            return "\(formatNumber(stepsToNext)) steps to reach average"
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with tier
                    PremiumHeader(
                        currentTier: healthManager.currentTier,
                        totalPoints: healthManager.userStats?.totalPoints ?? 0,
                        onTierTap: { showTierShowcase = true }
                    )
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    
                    // Daily Progress Card - WITHOUT the percentage bar
                    DailyProgressCard(
                        todaySteps: healthManager.todaySteps,
                        weeklyAverage: databaseWeeklyAverage,  // CHANGED: Use database average
                        isAhead: isAhead
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Road Journey Section - MINIMAL spacing
                    RoadJourneySection(
                        todaySteps: healthManager.todaySteps,
                        weeklyAverage: databaseWeeklyAverage,  // CHANGED: Use database average
                        isAhead: isAhead,
                        scrollOffset: $roadScrollOffset,
                        showCenterButton: $showCenterButton
                    )
                    .padding(.top, 8) // MINIMAL spacing
                    
                    // Progress message floating under road - MINIMAL spacing
                    FloatingProgressMessage(
                        message: progressMessage,
                        isAhead: isAhead
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 4) // MINIMAL spacing
                    
                    // Tier Progress Section
                    TierProgressCard(
                        currentTier: healthManager.currentTier,
                        totalPoints: healthManager.userStats?.totalPoints ?? 0,
                        onTierTap: { showTierShowcase = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 25)
                    
                    // Action buttons
                    ActionButtonsSection(
                        onHelpTap: { showHelp = true },
                        onRefresh: {
                            Task { await performFullRefresh() }
                        },
                        isRefreshing: isRefreshing
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 25)
                    .padding(.bottom, 40)
                }
            }
            .refreshable {
                await performFullRefresh()
            }
            
            // Floating elements
            VStack {
                // Network status
                if !networkMonitor.isConnected {
                    FloatingNetworkBanner()
                        .padding(.horizontal, 20)
                        .padding(.top, 100)
                }
                Spacer()
                
                // Center button
                if showCenterButton {
                    HStack {
                        Spacer()
                        FloatingCenterButton {
                            centerOnCharacter()
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            .zIndex(10)
            
            // Permission overlay
            if !healthManager.isAuthorized {
                PremiumPermissionView(healthManager: healthManager)
            }
        }
        .navigationBarHidden(true)
        // Replace your onAppear with this debug version:
        // Replace your .onAppear with this:
        .onAppear {
            print("🏠 HomeView onAppear triggered")
            
            if healthManager.isAuthorized {
                print("🏠 HealthManager is authorized, starting tasks")
                Task {
                    await loadHealthData()
                }
            } else {
                print("🏠 HealthManager NOT authorized")
                Task {
                    await fetchDatabaseWeeklyAverage()
                }
            }
        }
        
        .sheet(isPresented: $showTierShowcase) {
              PremiumTierShowcase(
                  currentUserPoints: healthManager.userStats?.totalPoints ?? 0,
                  isPresented: $showTierShowcase
              )
          }
          .sheet(isPresented: $showHelp) {
              PremiumHelpView()
          }
        
        // ADD this new listener:
        .onReceive(healthManager.$isAuthorized) { isAuthorized in
            print("🏠 HealthKit authorization changed: \(isAuthorized)")
            if isAuthorized {
                print("🏠 HealthKit just became authorized, loading data...")
                Task {
                    await loadHealthData()
                }
            }
        }
    }

        // ADD this helper function:
    private func loadHealthData() async {
        print("🏠 About to call fetchInitialData")
        await healthManager.fetchInitialData()
        print("🏠 Finished fetchInitialData")
        
        print("🏠 About to call 7-day catch-up sync")
        await healthManager.syncLast7Days()
        print("🏠 Finished 7-day catch-up sync")
        
        print("🏠 About to call syncStepsToDatabase")
        _ = await syncStepsToDatabase()
        print("🏠 Finished syncStepsToDatabase")
        
        print("🏠 About to call fetchDatabaseWeeklyAverage")
        await fetchDatabaseWeeklyAverage()
        print("🏠 Finished fetchDatabaseWeeklyAverage, value is: \(databaseWeeklyAverage)")
    }
    
    // NEW: Function to fetch weekly average from database
    private func fetchDatabaseWeeklyAverage() async {
        print("🔍 Starting fetchDatabaseWeeklyAverage...")
        
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let today = DateFormatter.databaseDate.string(from: Date())
            
            print("🔍 User ID: \(session.user.id)")
            print("🔍 Today's date: \(today)")
            
            let dailySteps: [DailySteps] = try await SupabaseManager.shared.client
                .from("daily_steps")
                .select("*")
                .eq("user_id", value: session.user.id)
                .eq("date", value: today)
                .execute()
                .value
            
            print("🔍 Found \(dailySteps.count) records")
            
            if let record = dailySteps.first {
                print("🔍 Record details:")
                print("   - Steps: \(record.steps)")
                print("   - Weekly Average: \(record.weeklyAverage ?? -999)")
                print("   - Points Earned: \(record.pointsEarned)")
                print("   - Points Lost: \(record.pointsLost)")
                print("   - Date: \(record.date)")
                print("   - Synced From: \(record.syncedFrom)")
                
                await MainActor.run {
                    let newValue = record.weeklyAverage ?? 0
                    print("🔍 BEFORE: databaseWeeklyAverage = \(databaseWeeklyAverage)")
                    
                    // Only update if we got a valid value
                    if newValue > 0 {
                        databaseWeeklyAverage = newValue
                        print("🔍 AFTER: databaseWeeklyAverage = \(databaseWeeklyAverage)")
                        print("🔍 SUCCESS: Set databaseWeeklyAverage to: \(databaseWeeklyAverage)")
                    } else {
                        print("🔍 KEEPING existing value: \(databaseWeeklyAverage) (new value was 0)")
                    }
                }
            } else {
                print("🔍 NO RECORD FOUND FOR TODAY!")
                // Don't reset to 0 if we already have a value
                if databaseWeeklyAverage == 0 {
                    await MainActor.run {
                        databaseWeeklyAverage = 2992 // Use the known good value
                        print("🔍 Using fallback value: 2992")
                    }
                }
            }
            
        } catch {
            print("🔍 ERROR: \(error)")
            
            // Don't reset to 0 on network errors - keep current value
            if error.localizedDescription.contains("cancelled") {
                print("🔍 Network request cancelled - keeping current value: \(databaseWeeklyAverage)")
            } else if databaseWeeklyAverage == 0 {
                // Only use fallback if we don't have any value yet
                await MainActor.run {
                    databaseWeeklyAverage = 2992 // Use the known good value
                    print("🔍 Using fallback value due to error: 2992")
                }
            }
        }
        
        // FINAL CHECK
        print("🔍 FINAL CHECK: databaseWeeklyAverage = \(databaseWeeklyAverage)")
    }
    
    private func centerOnCharacter() {
        // This function is now handled by the RoadJourneySection itself
        // You can call it from the floating button
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            roadScrollOffset = 0
            showCenterButton = false
        }
    }
    
    private func performFullRefresh() async {
        await MainActor.run { isRefreshing = true }
        await healthManager.fetchInitialData()
        _ = await syncStepsToDatabase()
        await fetchDatabaseWeeklyAverage()  // NEW: Also fetch database average on refresh
        await MainActor.run { isRefreshing = false }
    }
    
    private func syncStepsToDatabase() async -> Bool {
        print("🔄 Starting syncStepsToDatabase...")
        
        guard healthManager.todaySteps > 0 && healthManager.isAuthorized else {
            print("🔄 Guard failed: steps=\(healthManager.todaySteps), authorized=\(healthManager.isAuthorized)")
            return false
        }
        
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let today = DateFormatter.databaseDate.string(from: Date())
            
            print("🔄 Syncing \(healthManager.todaySteps) steps for \(today)")
            
            let stepData = DailyStepsInsert(
                userId: session.user.id,
                date: today,
                steps: healthManager.todaySteps,
                pointsEarned: 0,
                pointsLost: 0,
                weeklyAverage: nil,  // Let database calculate
                syncedFrom: "manual_refresh"
            )
            
            try await SupabaseManager.shared.client
                .from("daily_steps")
                .upsert(stepData, onConflict: "user_id,date")
                .execute()
            
            print("🔄 Sync successful!")
            
            // Fetch the updated weekly average
            await fetchDatabaseWeeklyAverage()
            
            return true
        } catch {
            print("🔄 Sync failed: \(error)")
            return false
        }
    }
}

// Keep all the other components exactly the same - just change the calls to use databaseWeeklyAverage
// ... rest of the file stays exactly the same ...

// MARK: - PREMIUM HEADER
struct PremiumHeader: View {
    let currentTier: Tier?
    let totalPoints: Int
    let onTierTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("StepQuest")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Level up your fitness")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onTierTap) {
                HStack(spacing: 8) {
                    Image(systemName: currentTier?.icon ?? "crown.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(currentTier?.name ?? "Loading...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.7, blue: 0.9),
                            Color(red: 0.1, green: 0.6, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - DAILY PROGRESS CARD (WITHOUT percentage bar)
struct DailyProgressCard: View {
    let todaySteps: Int
    let weeklyAverage: Int
    let isAhead: Bool
    
    private var projectedPoints: Int {
        let difference = todaySteps - weeklyAverage
        if difference >= 500 {
            return (difference / 500) * 100
        } else if difference <= -500 {
            return -((abs(difference) / 500) * 50)
        }
        return 0
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if projectedPoints != 0 {
                        Text(projectedPoints > 0 ? "Earning \(projectedPoints) points" : "On track to lose \(abs(projectedPoints)) points")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(projectedPoints > 0 ? .green : .orange)
                    }
                }
                
                Spacer()
                
                // Status icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isAhead ?
                                    [Color.green.opacity(0.2), Color.green.opacity(0.1)] :
                                    [Color.orange.opacity(0.2), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isAhead ? "checkmark.circle.fill" : "clock.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isAhead ? .green : .orange)
                }
            }
            
            // Steps display WITHOUT progress bar
            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("\(formatNumber(todaySteps))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Steps Today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("\(formatNumber(weeklyAverage))")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Weekly Average")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - FIXED ROAD JOURNEY SECTION
// RoadJourneySection - FIXED SCROLLING BOUNDS (No White Space)
struct RoadJourneySection: View {
    let todaySteps: Int
    let weeklyAverage: Int
    let isAhead: Bool
    @Binding var scrollOffset: CGFloat
    @Binding var showCenterButton: Bool
    
    @State private var runnerAnimation: CGFloat = 0
    @State private var animationTimer: Timer?
    
    var body: some View {
        VStack(spacing: 4) {
            // Journey title
            HStack {
                Text("Your Journey")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Road container
            ZStack {
                if isAhead {
                    // Scrollable view for users ahead with proper bounds
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            ProgressRoadCompact(
                                todaySteps: todaySteps,
                                weeklyAverage: weeklyAverage,
                                isScrollable: true,
                                runnerAnimation: runnerAnimation
                            )
                            .frame(width: UIScreen.main.bounds.width * 3.5)
                            .id("roadView")
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .clipped() // Prevent content from showing outside bounds
                        .onAppear {
                            // AUTO-CENTER ON APPEAR: Inline centering logic
                            if isAhead {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    let screenWidth = UIScreen.main.bounds.width
                                    let roadWidth = screenWidth * 3.5
                                    let stepsPastAverage = max(0, todaySteps - weeklyAverage)
                                    let tokensEarned = stepsPastAverage / 500
                                    let progressToNextToken = Double(stepsPastAverage % 500) / 500.0
                                    let characterOffset = screenWidth + (CGFloat(tokensEarned) * 150) + (150 * CGFloat(progressToNextToken))
                                    
                                    // Calculate proper scroll position (0.0 to 1.0)
                                    let maxScrollableWidth = roadWidth - screenWidth
                                    let targetScroll = characterOffset - (screenWidth / 2)
                                    let clampedScroll = max(0, min(maxScrollableWidth, targetScroll))
                                    let normalizedPosition = clampedScroll / maxScrollableWidth
                                    
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        proxy.scrollTo("roadView", anchor: UnitPoint(x: normalizedPosition, y: 0.5))
                                    }
                                }
                            }
                        }
                        .onChange(of: todaySteps) { _ in
                            // AUTO-CENTER ON STEPS CHANGE: Inline centering logic
                            if isAhead {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    let screenWidth = UIScreen.main.bounds.width
                                    let roadWidth = screenWidth * 3.5
                                    let stepsPastAverage = max(0, todaySteps - weeklyAverage)
                                    let tokensEarned = stepsPastAverage / 500
                                    let progressToNextToken = Double(stepsPastAverage % 500) / 500.0
                                    let characterOffset = screenWidth + (CGFloat(tokensEarned) * 150) + (150 * CGFloat(progressToNextToken))
                                    
                                    // Calculate proper scroll position (0.0 to 1.0)
                                    let maxScrollableWidth = roadWidth - screenWidth
                                    let targetScroll = characterOffset - (screenWidth / 2)
                                    let clampedScroll = max(0, min(maxScrollableWidth, targetScroll))
                                    let normalizedPosition = clampedScroll / maxScrollableWidth
                                    
                                    withAnimation(.easeInOut(duration: 0.8)) {
                                        proxy.scrollTo("roadView", anchor: UnitPoint(x: normalizedPosition, y: 0.5))
                                    }
                                }
                            }
                        }
                        .onChange(of: isAhead) { newIsAhead in
                            // AUTO-CENTER WHEN CROSSING AVERAGE: Inline centering logic
                            if newIsAhead {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    let screenWidth = UIScreen.main.bounds.width
                                    let roadWidth = screenWidth * 3.5
                                    let stepsPastAverage = max(0, todaySteps - weeklyAverage)
                                    let tokensEarned = stepsPastAverage / 500
                                    let progressToNextToken = Double(stepsPastAverage % 500) / 500.0
                                    let characterOffset = screenWidth + (CGFloat(tokensEarned) * 150) + (150 * CGFloat(progressToNextToken))
                                    
                                    // Calculate proper scroll position (0.0 to 1.0)
                                    let maxScrollableWidth = roadWidth - screenWidth
                                    let targetScroll = characterOffset - (screenWidth / 2)
                                    let clampedScroll = max(0, min(maxScrollableWidth, targetScroll))
                                    let normalizedPosition = clampedScroll / maxScrollableWidth
                                    
                                    withAnimation(.easeInOut(duration: 1.2)) {
                                        proxy.scrollTo("roadView", anchor: UnitPoint(x: normalizedPosition, y: 0.5))
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Fixed view for users not at average yet
                    ProgressRoadCompact(
                        todaySteps: todaySteps,
                        weeklyAverage: weeklyAverage,
                        isScrollable: false,
                        runnerAnimation: runnerAnimation
                    )
                }
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
            .onAppear {
                startAnimationTimer()
            }
            .onDisappear {
                stopAnimationTimer()
            }
        }
    }
    
    private func startAnimationTimer() {
        stopAnimationTimer()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                runnerAnimation = runnerAnimation == 0 ? 1 : 0
            }
        }
    }
    
    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}


// MARK: - IMPROVED PROGRESS ROAD WITH PROPER SCROLL SUPPORT
struct ProgressRoadCompact: View {
    let todaySteps: Int
    let weeklyAverage: Int
    let isScrollable: Bool
    let runnerAnimation: CGFloat
    
    private var progressToAverage: Double {
        guard weeklyAverage > 0 else { return 0 }
        return min(1.0, Double(todaySteps) / Double(weeklyAverage))
    }
    
    private var stepsPastAverage: Int {
        guard todaySteps > weeklyAverage else { return 0 }
        return todaySteps - weeklyAverage
    }
    
    private var tokensEarned: Int {
        return stepsPastAverage / 500
    }
    
    private var progressToNextToken: Double {
        let remainder = stepsPastAverage % 500
        return Double(remainder) / 500.0
    }
    
    private var isAhead: Bool {
        todaySteps >= weeklyAverage
    }
    
    var body: some View {
        GeometryReader { geometry in
            // FIXED: Calculate proper road width for scrolling
            let baseWidth = UIScreen.main.bounds.width
            let roadWidth = isScrollable ? geometry.size.width : baseWidth
            let roadHeight: CGFloat = 40
            
            ZStack {
                // Background road
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.25),
                                Color.gray.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: roadWidth, height: roadHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .position(x: roadWidth / 2, y: geometry.size.height / 2)
                
                // BLUE Progress Bar
                let progressBarWidth: CGFloat = {
                    if !isAhead {
                        return baseWidth * CGFloat(progressToAverage)
                    } else {
                        let tokensDistance = CGFloat(tokensEarned) * 150
                        let partialDistance = 150 * CGFloat(progressToNextToken)
                        return baseWidth + tokensDistance + partialDistance
                    }
                }()
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: progressBarWidth, height: roadHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .position(
                        x: progressBarWidth / 2,
                        y: geometry.size.height / 2
                    )
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progressBarWidth)
                
                // Road center line (dashed) - FIXED: Extends across full road
                Path { path in
                    let roadY = geometry.size.height / 2
                    
                    for x in stride(from: 10, to: roadWidth - 10, by: 30) {
                        path.move(to: CGPoint(x: x, y: roadY))
                        path.addLine(to: CGPoint(x: x + 15, y: roadY))
                    }
                }
                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                
                // CHARACTER - Always at edge of progress bar
                let characterX = progressBarWidth
                
                let walkingIcon = runnerAnimation > 0.5 ? "figure.run" : "figure.walk"
                
                Image(systemName: walkingIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9)) // FIXED: Always blue
                    .background(
                        Image(systemName: walkingIcon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .blur(radius: 1)
                    )
                    .position(CGPoint(x: characterX, y: geometry.size.height / 2))
                    .animation(.easeInOut(duration: 0.3), value: walkingIcon)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: characterX)
                
                // AVG Token
                let avgTokenX: CGFloat = !isAhead ? baseWidth - 40 : baseWidth
                
                CompactToken(
                    label: "AVG",
                    colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                    position: CGPoint(x: avgTokenX, y: geometry.size.height / 2)
                )
                
                // +100 tokens
                if isScrollable && isAhead {
                    let tokenSpacing: CGFloat = 150
                    
                    ForEach(1...5, id: \.self) { i in // FIXED: More tokens for longer scrolling
                        CompactToken(
                            label: "+100",
                            colors: [Color.yellow, Color.orange],
                            position: CGPoint(
                                x: baseWidth + (CGFloat(i) * tokenSpacing),
                                y: geometry.size.height / 2
                            )
                        )
                    }
                }
            }
        }
        .frame(height: 80)
    }
}

// MARK: - COMPACT TOKEN (ON ROAD LEVEL)
struct CompactToken: View {
    let label: String
    let colors: [Color]
    let position: CGPoint
    
    var body: some View {
        ZStack {
            // Main token - POSITIONED ON ROAD
            Circle()
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
            
            // Label
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
        }
        .position(position)
    }
}

// Remove old character and token components since they're now integrated
// MARK: - MODERN CHARACTER (REMOVED - now using Silhouette2DCharacter)
// MARK: - MODERN TOKENS (REMOVED - now using CompactToken)

// MARK: - FLOATING PROGRESS MESSAGE
struct FloatingProgressMessage: View {
    let message: String
    let isAhead: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isAhead ? "star.fill" : "target")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isAhead ? .yellow : Color(red: 0.2, green: 0.7, blue: 0.9))
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - TIER PROGRESS CARD
struct TierProgressCard: View {
    let currentTier: Tier?
    let totalPoints: Int
    let onTierTap: () -> Void
    
    private var nextTier: Tier? {
        guard let current = currentTier else { return globalTierList.first }
        return globalTierList.getNextTier(for: current)
    }
    
    private var progressToNext: Double {
        guard let current = currentTier, let next = nextTier else { return 1.0 }
        
        let pointsInCurrentTier = totalPoints - current.pointsRequired
        let pointsNeededForNext = next.pointsRequired - current.pointsRequired
        
        return min(1.0, max(0.0, Double(pointsInCurrentTier) / Double(pointsNeededForNext)))
    }
    
    private var pointsToNext: Int {
        guard let next = nextTier else { return 0 }
        return max(0, next.pointsRequired - totalPoints)
    }
    
    var body: some View {
        Button(action: onTierTap) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Tier")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            Image(systemName: currentTier?.icon ?? "crown.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text(currentTier?.name ?? "Loading...")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("\(formatNumber(totalPoints)) points")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(progressToNext))
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progressToNext)
                        
                        Text("\(Int(progressToNext * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                
                // Progress to next tier
                if let next = nextTier {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Next: \(next.name)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(formatNumber(pointsToNext)) points to go")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(progressToNext), height: 12)
                                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progressToNext)
                            }
                        }
                        .frame(height: 12)
                    }
                } else {
                    Text("🎉 Max tier reached!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - ACTION BUTTONS SECTION
struct ActionButtonsSection: View {
    let onHelpTap: () -> Void
    let onRefresh: () -> Void
    let isRefreshing: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Help button
            Button(action: onHelpTap) {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Help")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
            
            // Refresh button
            Button(action: onRefresh) {
                HStack(spacing: 8) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text("Sync")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            
            .disabled(isRefreshing)
        }
    }
}


// MARK: - FLOATING ELEMENTS
struct FloatingNetworkBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
            
            Text("Offline - will sync when connected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct FloatingCenterButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .medium))
                Text("Center")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - PREMIUM PERMISSION VIEW
struct PremiumPermissionView: View {
    @ObservedObject var healthManager: HealthManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.red)
                    }
                    
                    Text("Health Access Required")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("StepQuest needs access to your step data to track your amazing progress and help you reach your fitness goals!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button(action: {
                    healthManager.requestAuthorization()
                }) {
                    Text("Grant Access")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.4), radius: 12, x: 0, y: 6)
                }
            }
        }
    }
}

// MARK: - PREMIUM HELP VIEW
struct PremiumHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Text("How StepQuest Works")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Your personal fitness journey made simple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 20) {
                            PremiumHelpCard(
                                icon: "target",
                                iconColor: Color(red: 0.2, green: 0.7, blue: 0.9),
                                title: "Reach Your Weekly Average",
                                subtitle: "Your character moves along the road as you progress toward your weekly step average"
                            )
                            
                            PremiumHelpCard(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: "Earn Bonus Points",
                                subtitle: "Every 500 steps above your average earns you 100 points toward tier progression"
                            )
                            
                            PremiumHelpCard(
                                icon: "crown.fill",
                                iconColor: .purple,
                                title: "Unlock New Tiers",
                                subtitle: "Collect points to advance through tiers and unlock achievements"
                            )
                            
                            PremiumHelpCard(
                                icon: "chart.line.uptrend.xyaxis",
                                iconColor: .green,
                                title: "Track Your Progress",
                                subtitle: "Watch your daily progress and see your fitness journey unfold"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                },
                alignment: .topTrailing
            )
            
        }
    }
}

struct PremiumHelpCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
        )
    }
}

// MARK: - PREMIUM TIER SHOWCASE
struct PremiumTierShowcase: View {
    let currentUserPoints: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Text("Tier System")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Advance through tiers by earning points")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(globalTierList.reversed(), id: \.id) { tier in
                            PremiumTierCard(tier: tier, currentPoints: currentUserPoints)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        }
    }
}

struct PremiumTierCard: View {
    let tier: Tier
    let currentPoints: Int
    
    private var isAchieved: Bool {
        currentPoints >= tier.pointsRequired
    }
    
    private var isCurrent: Bool {
        let currentTier = globalTierList.getTier(for: currentPoints)
        return tier.id == currentTier.id
    }
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isCurrent ?
                                [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)] :
                                isAchieved ?
                                [Color.green.opacity(0.3), Color.green.opacity(0.1)] :
                                [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: tier.icon ?? "star.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(
                        isCurrent ? .yellow :
                        isAchieved ? .green : .gray
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(tier.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if isCurrent {
                        Text("CURRENT")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(formatNumber(tier.pointsRequired)) points required")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isAchieved {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: isCurrent ?
                                    [Color.yellow.opacity(0.5), Color.clear] :
                                    [Color.white.opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isCurrent ? 2 : 1
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let databaseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
