// GroupDetailScreen.swift - UPDATED WITH CLEAN READABLE DESIGN
// Full navigation screen replacement for GroupDetailView

import SwiftUI

struct GroupDetailScreen: View {
    let group: GroupWithDetails
    @ObservedObject var groupsManager: GroupsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var leaderboard: [GroupLeaderboardEntry] = []
    @State private var isLoadingLeaderboard = false
    @State private var showInviteOptions = false
    @State private var showLeaveConfirmation = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Simple, clean background
            Color(red: 0.98, green: 0.99, blue: 1.0)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Clean readable header
                GroupDetailCoolHeader(
                    group: group,
                    scrollOffset: scrollOffset,
                    onInvite: { showInviteOptions = true },
                    onLeave: { showLeaveConfirmation = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Leaderboard content
                if isLoadingLeaderboard {
                    Spacer()
                    LoadingLeaderboardView()
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 20) {
                                // Period info card with cool styling
                                CoolCurrentPeriodCard(resetPeriod: group.leaderboardResetPeriod)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                
                                // Leaderboard section
                                if leaderboard.isEmpty {
                                    CoolEmptyLeaderboardView()
                                        .padding(.horizontal, 20)
                                        .padding(.top, 40)
                                } else {
                                    VStack(spacing: 0) {
                                        // Leaderboard header
                                        HStack {
                                            Text("Leaderboard")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                            
                                            Spacer()
                                            
                                            Text("\(leaderboard.count) members")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 16)
                                        
                                        // Leaderboard entries with cool animations
                                        ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                                            CoolGroupLeaderboardRow(
                                                entry: entry,
                                                position: index + 1,
                                                animationDelay: Double(index) * 0.1
                                            )
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 100)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            scrollOffset = geo.frame(in: .global).minY
                                        }
                                        .onChange(of: geo.frame(in: .global).minY) { value in
                                            scrollOffset = value
                                        }
                                }
                            )
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadLeaderboard()
        }
        .refreshable {
            loadLeaderboard()
        }
        .sheet(isPresented: $showInviteOptions) {
            InviteOptionsView(group: group, groupsManager: groupsManager)
        }
        .alert("Leave Group", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                leaveGroup()
            }
        } message: {
            Text("Are you sure you want to leave '\(group.name)'? You'll need an invite code to rejoin.")
        }
    }
    
    private func loadLeaderboard() {
        isLoadingLeaderboard = true
        
        Task {
            let entries = await groupsManager.getGroupLeaderboard(groupId: group.id)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.leaderboard = entries
                    self.isLoadingLeaderboard = false
                }
            }
        }
    }
    
    private func leaveGroup() {
        Task {
            let success = await groupsManager.leaveGroup(groupId: group.id)
            
            await MainActor.run {
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Clean Readable Header

struct GroupDetailCoolHeader: View {
    let group: GroupWithDetails
    let scrollOffset: CGFloat
    let onInvite: () -> Void
    let onLeave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Back button and header - ALWAYS READABLE
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Groups")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                }
                
                Spacer()
            }
            
            // Main group info with clean design
            VStack(spacing: 16) {
                // Title and admin badge
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(group.name)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary) // Simple, readable color
                                .lineLimit(2)
                            
                            if group.userRole == .admin {
                                Text("ADMIN")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 0.2, green: 0.7, blue: 0.9))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.4), radius: 4, x: 0, y: 2)
                            }
                        }
                        
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    
                    Spacer()
                }
                
                // Cool stats row with glassmorphism
                HStack(spacing: 0) {
                    CoolGroupStatItem(
                        icon: "person.2.fill",
                        value: "\(group.memberCount)",
                        label: group.memberCount == 1 ? "Member" : "Members",
                        color: Color(red: 0.2, green: 0.7, blue: 0.9)
                    )
                    
                    Spacer()
                    
                    CoolGroupStatItem(
                        icon: group.leaderboardResetPeriod.icon,
                        value: group.leaderboardResetPeriod.displayName,
                        label: "Resets",
                        color: Color(red: 0.3, green: 0.6, blue: 0.8)
                    )
                    
                    Spacer()
                    
                    if let rank = group.userRank {
                        CoolGroupStatItem(
                            icon: "trophy.fill",
                            value: "#\(rank)",
                            label: "Your Rank",
                            color: Color.orange
                        )
                    } else {
                        CoolGroupStatItem(
                            icon: "trophy.fill",
                            value: "--",
                            label: "Your Rank",
                            color: Color.gray
                        )
                    }
                }
                
                // Action buttons with cool effects
                HStack(spacing: 16) {
                    Button(action: onInvite) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Invite Friends")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
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
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    if group.userRole != .admin {
                        Button(action: onLeave) {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Leave")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(Color.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.red.opacity(0.6), lineWidth: 2)
                                    .background(.ultraThinMaterial)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            // Removed the crazy scaling and opacity effects that made it blurry
        }
    }
}

// MARK: - Cool Group Stat Item

struct CoolGroupStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Cool Current Period Card

struct CoolCurrentPeriodCard: View {
    let resetPeriod: LeaderboardResetPeriod
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: resetPeriod.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Period")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(currentPeriodText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next Reset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(nextResetText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
    
    private var currentPeriodText: String {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        
        switch resetPeriod {
        case .daily:
            formatter.dateFormat = "EEEE, MMM d"
            return "Today - \(formatter.string(from: today))"
            
        case .weekly:
            // FIXED: Calculate the actual current week (Sunday to Saturday)
            let weekday = calendar.component(.weekday, from: today)
            let daysFromSunday = weekday - 1
            
            let startOfWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) ?? today
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today
            
            formatter.dateFormat = "MMM d"
            return "This Week - \(formatter.string(from: startOfWeek)) to \(formatter.string(from: endOfWeek))"
            
        case .biweekly:
            formatter.dateFormat = "MMM d"
            return "Current 2-Week Period"
            
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return "This Month - \(formatter.string(from: today))"
        }
    }
    
    private var nextResetText: String {
        let calendar = Calendar.current
        let today = Date()
        
        switch resetPeriod {
        case .daily:
            return "Tomorrow"
        case .weekly:
            if let nextMonday = calendar.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) {
                let formatter = RelativeDateTimeFormatter()
                return formatter.localizedString(for: nextMonday, relativeTo: today)
            }
            return "Next Monday"
        case .biweekly:
            return "In 2 weeks"
        case .monthly:
            return "Next month"
        }
    }
}

// MARK: - Cool Leaderboard Row

struct CoolGroupLeaderboardRow: View {
    let entry: GroupLeaderboardEntry
    let position: Int
    let animationDelay: Double
    @State private var hasAppeared = false
    
    var rankColor: Color {
        switch position {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return Color(red: 0.2, green: 0.7, blue: 0.9)
        }
    }
    
    var rankIcon: String {
        switch position {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "person.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank indicator with cool styling
            ZStack {
                Circle()
                    .fill(
                        entry.isCurrentUser ?
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [rankColor.opacity(0.8), rankColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: rankColor.opacity(0.3), radius: 6, x: 0, y: 3)
                
                if position <= 3 {
                    Image(systemName: rankIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(position)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.username)
                        .font(.system(size: 16, weight: entry.isCurrentUser ? .bold : .semibold))
                        .foregroundColor(entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .primary)
                    
                    if entry.isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.2, green: 0.7, blue: 0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(entry.totalSteps) steps")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Steps with cool number formatting
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.totalSteps.formatted())")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("steps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(entry.isCurrentUser ? .ultraThinMaterial : .regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            entry.isCurrentUser ?
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.4), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: entry.isCurrentUser ? 2 : 0
                        )
                )
                .shadow(
                    color: entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2) : Color.black.opacity(0.05),
                    radius: entry.isCurrentUser ? 12 : 6,
                    x: 0,
                    y: entry.isCurrentUser ? 6 : 3
                )
        )
        .scaleEffect(hasAppeared ? 1.0 : 0.8)
        .opacity(hasAppeared ? 1.0 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(animationDelay), value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Loading Views

struct LoadingLeaderboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Animated loading indicator
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.6))
                        .frame(width: 60, height: 60)
                        .scaleEffect(0.5)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: UUID()
                        )
                }
            }
            
            Text("Loading leaderboard...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct CoolEmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50, weight: .thin))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("No Activity Yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Start walking to see your group's\nleaderboard come to life!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Custom Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
