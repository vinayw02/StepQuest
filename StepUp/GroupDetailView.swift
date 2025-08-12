// GroupDetailView.swift - CREATE THIS AS A NEW FILE

import SwiftUI

struct GroupDetailView: View {
    let group: GroupWithDetails
    @ObservedObject var groupsManager: GroupsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var leaderboard: [GroupLeaderboardEntry] = []
    @State private var isLoadingLeaderboard = false
    @State private var showInviteOptions = false
    @State private var showLeaveConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Blue Premium background
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
                    GroupDetailHeader(
                        group: group,
                        onInvite: { showInviteOptions = true },
                        onLeave: { showLeaveConfirmation = true }
                    )
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    
                    // Leaderboard
                    if isLoadingLeaderboard {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                            
                            Text("Loading leaderboard...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                // Current period info
                                CurrentPeriodCard(resetPeriod: group.leaderboardResetPeriod)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                
                                // Leaderboard entries
                                if leaderboard.isEmpty {
                                    EmptyLeaderboardView()
                                        .padding(.horizontal, 20)
                                        .padding(.top, 40)
                                } else {
                                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                                        GroupLeaderboardRow(
                                            entry: entry,
                                            position: index + 1
                                        )
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
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
        .overlay(
            VStack {
                HStack {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                    .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
            },
            alignment: .topLeading
        )
    }
    
    private func loadLeaderboard() {
        isLoadingLeaderboard = true
        
        Task {
            let entries = await groupsManager.getGroupLeaderboard(groupId: group.id)
            
            await MainActor.run {
                self.leaderboard = entries
                self.isLoadingLeaderboard = false
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

// MARK: - Group Detail Header

struct GroupDetailHeader: View {
    let group: GroupWithDetails
    let onInvite: () -> Void
    let onLeave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title and description
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(group.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if group.userRole == .admin {
                        Text("ADMIN")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.2, green: 0.7, blue: 0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                
                if let description = group.description, !description.isEmpty {
                    HStack {
                        Text(description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        
                        Spacer()
                    }
                }
            }
            
            // Stats row
            HStack(spacing: 24) {
                GroupDetailStat(
                    icon: group.leaderboardResetPeriod.icon,
                    title: group.leaderboardResetPeriod.shortDisplayName,
                    subtitle: "Reset Period"
                )
                
                GroupDetailStat(
                    icon: "person.2.fill",
                    title: "\(group.memberCount)",
                    subtitle: "Members"
                )
                
                if let rank = group.userRank {
                    GroupDetailStat(
                        icon: "trophy.fill",
                        title: "#\(rank)",
                        subtitle: "Your Rank"
                    )
                } else {
                    GroupDetailStat(
                        icon: "trophy.fill",
                        title: "--",
                        subtitle: "Your Rank"
                    )
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: onInvite) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                        Text("Invite")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                if group.userRole != .admin {
                    Button(action: onLeave) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .medium))
                            Text("Leave")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 2)
                                .background(Color.white.opacity(0.8))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

struct GroupDetailStat: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Current Period Card

struct CurrentPeriodCard: View {
    let resetPeriod: LeaderboardResetPeriod
    
    private var periodText: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let today = Date()
        
        switch resetPeriod {
        case .daily:
            formatter.dateFormat = "MMM d"
            return "Today - \(formatter.string(from: today))"
        case .weekly:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
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
            return "Resets tomorrow"
        case .weekly:
            if let nextMonday = calendar.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) {
                let formatter = RelativeDateTimeFormatter()
                return "Resets \(formatter.localizedString(for: nextMonday, relativeTo: today))"
            }
            return "Resets next Monday"
        case .biweekly:
            return "Resets every 2 weeks"
        case .monthly:
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: calendar.date(from: calendar.dateComponents([.year, .month], from: today))!)) {
                let formatter = RelativeDateTimeFormatter()
                return "Resets \(formatter.localizedString(for: nextMonth, relativeTo: today))"
            }
            return "Resets next month"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: resetPeriod.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                
                Text("Current Period")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text(periodText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                HStack {
                    Text(nextResetText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Group Leaderboard Row

struct GroupLeaderboardRow: View {
    let entry: GroupLeaderboardEntry
    let position: Int
    
    private var rankColor: Color {
        switch position {
        case 1:
            return .yellow
        case 2:
            return .gray
        case 3:
            return .orange
        default:
            return entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary
        }
    }
    
    private var rankIcon: String {
        switch position {
        case 1:
            return "crown.fill"
        case 2:
            return "medal.fill"
        case 3:
            return "medal.fill"
        default:
            return "circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if position <= 3 {
                    Image(systemName: rankIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(rankColor)
                } else {
                    Text("\(position)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(rankColor)
                }
            }
            
            // Avatar
            ZStack {
                Circle()
                    .fill(entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2) : Color.gray.opacity(0.2))
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
                            .foregroundColor(entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary)
                    }
                    .frame(width: 40, height: 40)
                } else {
                    Text(entry.username.prefix(1).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .secondary)
                }
            }
            
            // Username
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.body)
                    .fontWeight(entry.isCurrentUser ? .semibold : .medium)
                    .foregroundColor(.primary)
                
                if entry.isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
            }
            
            Spacer()
            
            // Steps
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatNumber(entry.totalSteps))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9) : .primary)
                
                Text("steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.05) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            entry.isCurrentUser ? Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Empty Leaderboard View

struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No data yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Start walking to see the leaderboard!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}
