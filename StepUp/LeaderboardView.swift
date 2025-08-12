// UPDATED LeaderboardView.swift with Blue Theme
import SwiftUI
import Supabase

struct LeaderboardView: View {
    @State private var selectedTab = 0
    @State private var selectedPeriod = 0
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var userRankings: UserRankings?
    @State private var isLoading = false
    @State private var animateAppearance = false
    @State private var dataTask: Task<Void, Never>?
    
    private let tabs = ["Global", "Friends"]
    private let periods = ["Daily", "Weekly"]
    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // BLUE Premium background
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
                
                VStack(spacing: 0) {
                    // Header
                    BlueLeaderboardHeader()
                        .padding(.top, 10)
                        .padding(.horizontal, 20)
                    
                    // Premium Tab Selection with Icons
                    BlueTabSelector(
                        tabs: tabs,
                        selectedTab: $selectedTab
                    )
                    .padding(.top, 20)
                    
                    // Period Selection
                    BluePeriodSelector(
                        periods: periods,
                        selectedPeriod: $selectedPeriod
                    )
                    
                    // Compact User Ranking Summary
                    if let rankings = userRankings {
                        BlueUserRankingSummary(rankings: rankings, selectedTab: selectedTab, selectedPeriod: selectedPeriod)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                    
                    // Leaderboard Content
                    if isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                            
                            Text("Loading rankings...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                // Premium Top 3
                                if leaderboardData.count >= 3 {
                                    BlueTopThreeView(
                                        topThree: Array(leaderboardData.prefix(3))
                                    )
                                    .scaleEffect(animateAppearance ? 1.0 : 0.8)
                                    .opacity(animateAppearance ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: animateAppearance)
                                }
                                
                                // Remaining Rankings
                                ForEach(Array(leaderboardData.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                                    BlueLeaderboardRow(
                                        entry: entry,
                                        rank: entry.rank,
                                        isCurrentUser: entry.isCurrentUser
                                    )
                                    .scaleEffect(animateAppearance ? 1.0 : 0.9)
                                    .opacity(animateAppearance ? 1.0 : 0.0)
                                    .animation(
                                        .spring(response: 0.6, dampingFraction: 0.8)
                                        .delay(0.2 + Double(index) * 0.05),
                                        value: animateAppearance
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadLeaderboard()
            withAnimation {
                animateAppearance = true
            }
        }
        .onChange(of: selectedTab) { _ in
            loadLeaderboard()
        }
        .onChange(of: selectedPeriod) { _ in
            loadLeaderboard()
        }
        .onDisappear {
            dataTask?.cancel()
        }
        .refreshable {
            await refreshLeaderboard()
        }
    }
    
    // Keep all existing methods unchanged...
    private func loadLeaderboard() {
        dataTask?.cancel()
        
        dataTask = Task {
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isLoading = true
                animateAppearance = false
            }
            
            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }
            
            do {
                let rankings = try await fetchUserRankings()
                let data = try await fetchLeaderboardData()
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    userRankings = rankings
                    leaderboardData = data
                    withAnimation {
                        animateAppearance = true
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Error loading leaderboard: \(error)")
                
                await MainActor.run {
                    leaderboardData = generateSampleLeaderboard()
                    withAnimation {
                        animateAppearance = true
                    }
                }
            }
        }
    }
    
    private func refreshLeaderboard() async {
        do {
            let session = try await supabase.auth.session
            
            try await supabase
                .rpc("refresh_user_friend_rankings", params: ["target_user_id": session.user.id.uuidString])
                .execute()
            
            await loadLeaderboardData()
            
        } catch {
            print("Error refreshing leaderboard: \(error)")
        }
    }
    
    private func loadLeaderboardData() async {
        let rankings = try? await fetchUserRankings()
        let data = try? await fetchLeaderboardData()
        
        await MainActor.run {
            userRankings = rankings
            leaderboardData = data ?? []
        }
    }
    
    private func fetchUserRankings() async throws -> UserRankings {
        let session = try await supabase.auth.session
        let today = DateFormatter.databaseDate.string(from: Date())
        
        let rankings: [UserRankingResponse] = try await supabase
            .from("leaderboard_cache")
            .select("global_daily_rank, global_weekly_rank, friends_daily_rank, friends_weekly_rank, daily_steps, weekly_steps")
            .eq("user_id", value: session.user.id)
            .eq("date", value: today)
            .execute()
            .value
        
        if let ranking = rankings.first {
            return UserRankings(
                globalDaily: ranking.globalDailyRank,
                globalWeekly: ranking.globalWeeklyRank,
                friendsDaily: ranking.friendsDailyRank,
                friendsWeekly: ranking.friendsWeeklyRank,
                todaySteps: ranking.dailySteps,
                weeklySteps: ranking.weeklySteps
            )
        } else {
            return UserRankings(
                globalDaily: nil,
                globalWeekly: nil,
                friendsDaily: nil,
                friendsWeekly: nil,
                todaySteps: 0,
                weeklySteps: 0
            )
        }
    }
    
    private func fetchLeaderboardData() async throws -> [LeaderboardEntry] {
        let session = try await supabase.auth.session
        let currentUserId = session.user.id
        let today = DateFormatter.databaseDate.string(from: Date())
        
        let leaderboardType: String
        switch (selectedTab, selectedPeriod) {
        case (0, 0): leaderboardType = "global_daily"
        case (0, 1): leaderboardType = "global_weekly"
        case (1, 0): leaderboardType = "friends_daily"
        case (1, 1): leaderboardType = "friends_weekly"
        default: leaderboardType = "global_daily"
        }
        
        do {
            let rpcResponse = try await supabase
                .rpc("get_leaderboard_data", params: [
                    "leaderboard_type": leaderboardType,
                    "target_date": today,
                    "user_id_filter": currentUserId.uuidString,
                    "limit_count": "50"
                ])
                .execute()
            
            let jsonData = rpcResponse.data
            if let results = try? JSONDecoder().decode([LeaderboardRPCResult].self, from: jsonData) {
                
                return results.map { result in
                    LeaderboardEntry(
                        id: result.userId,
                        username: result.username,
                        avatarUrl: result.avatarUrl,
                        steps: result.steps,
                        isCurrentUser: result.isCurrentUser,
                        rank: result.rank
                    )
                }
            } else {
                throw NSError(domain: "RPC", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RPC response"])
            }
            
        } catch {
            print("RPC failed, using direct query: \(error)")
            return try await fetchLeaderboardDataDirect()
        }
    }
    
    private func fetchLeaderboardDataDirect() async throws -> [LeaderboardEntry] {
        let session = try await supabase.auth.session
        let currentUserId = session.user.id
        let today = DateFormatter.databaseDate.string(from: Date())
        
        let orderField: String
        let stepsField: String
        
        switch (selectedTab, selectedPeriod) {
        case (0, 0):
            orderField = "global_daily_rank"
            stepsField = "daily_steps"
        case (0, 1):
            orderField = "global_weekly_rank"
            stepsField = "weekly_steps"
        case (1, 0):
            orderField = "friends_daily_rank"
            stepsField = "daily_steps"
        case (1, 1):
            orderField = "friends_weekly_rank"
            stepsField = "weekly_steps"
        default:
            orderField = "global_daily_rank"
            stepsField = "daily_steps"
        }
        
        var query = supabase
            .from("leaderboard_cache")
            .select("user_id, daily_steps, weekly_steps, \(orderField), user_profiles(username, avatar_url)")
            .eq("date", value: today)
        
        if selectedTab == 1 {
            let friendships: [Friendship] = try await supabase
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: currentUserId)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            var friendIds = friendships.map { $0.friendId }
            friendIds.append(currentUserId)
            
            query = query.in("user_id", values: friendIds)
        }
        
        let results: [LeaderboardCacheResponse] = try await query
            .order(orderField, ascending: true)
            .limit(50)
            .execute()
            .value
        
        return results
            .compactMap { result -> LeaderboardEntry? in
                guard let rank = result.getRank(for: orderField) else { return nil }
                
                let steps = stepsField == "daily_steps" ? result.dailySteps : result.weeklySteps
                
                return LeaderboardEntry(
                    id: result.userId,
                    username: result.userProfiles?.username ?? "Unknown",
                    avatarUrl: result.userProfiles?.avatarUrl,
                    steps: steps,
                    isCurrentUser: result.userId == currentUserId,
                    rank: rank
                )
            }
            .sorted { $0.rank < $1.rank }
    }
    
    private func generateSampleLeaderboard() -> [LeaderboardEntry] {
        let sampleData = [
            LeaderboardEntry(id: UUID(), username: "sarah_walker", avatarUrl: nil, steps: 15420, isCurrentUser: false, rank: 1),
            LeaderboardEntry(id: UUID(), username: "mike_runner", avatarUrl: nil, steps: 12350, isCurrentUser: false, rank: 2),
            LeaderboardEntry(id: UUID(), username: "emma_steps", avatarUrl: nil, steps: 11280, isCurrentUser: false, rank: 3),
            LeaderboardEntry(id: UUID(), username: "You", avatarUrl: nil, steps: 10180, isCurrentUser: true, rank: 4),
            LeaderboardEntry(id: UUID(), username: "alex_stride", avatarUrl: nil, steps: 9750, isCurrentUser: false, rank: 5)
        ]
        return sampleData
    }
}

// MARK: - BLUE THEMED COMPONENTS

struct BlueLeaderboardHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Leaderboard")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("See how you rank")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            }
        }
    }
}

struct BlueTabSelector: View {
    let tabs: [String]
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: index == 0 ? "globe.americas.fill" : "person.2.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(tab)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(selectedTab == index ? .white : .primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(selectedTab == index ?
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: selectedTab == index ? Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

struct BluePeriodSelector: View {
    let periods: [String]
    @Binding var selectedPeriod: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(periods.enumerated()), id: \.offset) { index, period in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedPeriod = index
                    }
                }) {
                    Text(period)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == index ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(selectedPeriod == index ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.1) : Color.clear)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

struct BlueUserRankingSummary: View {
    let rankings: UserRankings
    let selectedTab: Int
    let selectedPeriod: Int
    
    private var currentRank: Int? {
        switch (selectedTab, selectedPeriod) {
        case (0, 0): return rankings.globalDaily
        case (0, 1): return rankings.globalWeekly
        case (1, 0): return rankings.friendsDaily
        case (1, 1): return rankings.friendsWeekly
        default: return nil
        }
    }
    
    private var rankingTitle: String {
        switch (selectedTab, selectedPeriod) {
        case (0, 0): return "Global Daily"
        case (0, 1): return "Global Weekly"
        case (1, 0): return "Friends Daily"
        case (1, 1): return "Friends Weekly"
        default: return "Rank"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                if let rank = currentRank {
                    Text("#\(rank)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                } else {
                    Text("--")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                Text("Your \(rankingTitle) Rank")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 20)
            
            VStack(spacing: 2) {
                let steps = selectedPeriod == 0 ? rankings.todaySteps : rankings.weeklySteps
                Text("\(steps)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(selectedPeriod == 0 ? "Today's Steps" : "Weekly Steps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct BlueTopThreeView: View {
    let topThree: [LeaderboardEntry]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Top 3")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                // 2nd Place
                if topThree.count > 1 {
                    BlueTopThreeSpot(
                        entry: topThree[1],
                        rank: 2,
                        accentColor: .gray
                    )
                }
                
                // 1st Place (larger)
                if topThree.count > 0 {
                    BlueTopThreeSpot(
                        entry: topThree[0],
                        rank: 1,
                        accentColor: Color(red: 0.2, green: 0.7, blue: 0.9),
                        isWinner: true
                    )
                }
                
                // 3rd Place
                if topThree.count > 2 {
                    BlueTopThreeSpot(
                        entry: topThree[2],
                        rank: 3,
                        accentColor: .orange
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.1), radius: 15, x: 0, y: 8)
        )
    }
}

struct BlueTopThreeSpot: View {
    let entry: LeaderboardEntry
    let rank: Int
    let accentColor: Color
    let isWinner: Bool
    
    init(entry: LeaderboardEntry, rank: Int, accentColor: Color, isWinner: Bool = false) {
        self.entry = entry
        self.rank = rank
        self.accentColor = accentColor
        self.isWinner = isWinner
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: isWinner ? 80 : 70, height: isWinner ? 80 : 70)
                
                Circle()
                    .stroke(accentColor, lineWidth: 3)
                    .frame(width: isWinner ? 80 : 70, height: isWinner ? 80 : 70)
                
                Image(systemName: rank == 1 ? "trophy.fill" : "medal.fill")
                    .font(.system(size: isWinner ? 28 : 24))
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(accentColor))
                    .offset(x: 25, y: -25)
            }
            
            VStack(spacing: 4) {
                Text(entry.username)
                    .font(isWinner ? .headline : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(entry.steps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .scaleEffect(isWinner ? 1.1 : 1.0)
    }
}

struct BlueLeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Text("\(rank)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary)
            }
            
            // Avatar
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                if let avatarUrl = entry.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                    } placeholder: {
                        Text(entry.username.prefix(1).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary)
                    }
                    .frame(width: 40, height: 40)
                } else {
                    Text(entry.username.prefix(1).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary)
                }
            }
            
            // Username
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.body)
                    .fontWeight(isCurrentUser ? .semibold : .medium)
                    .foregroundColor(.primary)
                
                if isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
            }
            
            Spacer()
            
            // Steps
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.steps)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .primary)
                
                Text("steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.05) : Color(.systemGray6).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
}

// Keep all existing data models unchanged
struct LeaderboardCacheResponse: Codable {
    let userId: UUID
    let dailySteps: Int
    let weeklySteps: Int
    let globalDailyRank: Int?
    let globalWeeklyRank: Int?
    let friendsDailyRank: Int?
    let friendsWeeklyRank: Int?
    let userProfiles: UserProfileLeaderboard?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case dailySteps = "daily_steps"
        case weeklySteps = "weekly_steps"
        case globalDailyRank = "global_daily_rank"
        case globalWeeklyRank = "global_weekly_rank"
        case friendsDailyRank = "friends_daily_rank"
        case friendsWeeklyRank = "friends_weekly_rank"
        case userProfiles = "user_profiles"
    }
    
    func getRank(for field: String) -> Int? {
        switch field {
        case "global_daily_rank": return globalDailyRank
        case "global_weekly_rank": return globalWeeklyRank
        case "friends_daily_rank": return friendsDailyRank
        case "friends_weekly_rank": return friendsWeeklyRank
        default: return nil
        }
    }
}

struct LeaderboardEntry: Identifiable {
    let id: UUID
    let username: String
    let avatarUrl: String?
    let steps: Int
    let isCurrentUser: Bool
    let rank: Int
}

struct UserProfileLeaderboard: Codable {
    let username: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
    }
}

struct LeaderboardRPCResult: Codable {
    let userId: UUID
    let username: String
    let avatarUrl: String?
    let steps: Int
    let rank: Int
    let isCurrentUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case steps
        case rank
        case isCurrentUser = "is_current_user"
    }
}
