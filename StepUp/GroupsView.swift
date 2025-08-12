// GroupsView.swift - Updated to use NavigationLink instead of sheet

import SwiftUI
import MessageUI

struct GroupsView: View {
    @StateObject private var groupsManager = GroupsManager()
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    
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
                    GroupsHeader(
                        onCreateGroup: { showCreateGroup = true },
                        onJoinGroup: { showJoinGroup = true }
                    )
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    
                    if groupsManager.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                            
                            Text("Loading groups...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if groupsManager.userGroups.isEmpty {
                        EmptyGroupsView(
                            onCreateGroup: { showCreateGroup = true },
                            onJoinGroup: { showJoinGroup = true }
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(groupsManager.userGroups) { groupWithDetails in
                                    NavigationLink(destination: GroupDetailScreen(group: groupWithDetails, groupsManager: groupsManager)) {
                                        GroupCard(
                                            groupWithDetails: groupWithDetails,
                                            onShare: {
                                                shareGroup(groupWithDetails)
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle()) // Prevents NavigationLink styling issues
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Ensures proper navigation on all devices
        .refreshable {
            await groupsManager.loadUserGroups()
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView(groupsManager: groupsManager)
        }
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupView(groupsManager: groupsManager)
        }
        .alert("Groups", isPresented: $groupsManager.showAlert) {
            Button("OK") { }
        } message: {
            Text(groupsManager.alertMessage)
        }
    }
    
    private func shareGroup(_ groupWithDetails: GroupWithDetails) {
        let group = Group(
            id: groupWithDetails.id,
            name: groupWithDetails.name,
            description: groupWithDetails.description,
            createdBy: groupWithDetails.createdBy,
            leaderboardResetPeriod: groupWithDetails.leaderboardResetPeriod,
            inviteCode: groupWithDetails.inviteCode,
            isActive: groupWithDetails.isActive,
            memberCount: groupWithDetails.memberCount,
            createdAt: groupWithDetails.createdAt,
            updatedAt: groupWithDetails.updatedAt
        )
        groupsManager.shareGroupInviteLink(group: group)
    }
}

// MARK: - Updated Group Card (removed onTap since we're using NavigationLink)

struct GroupCard: View {
    let groupWithDetails: GroupWithDetails
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(groupWithDetails.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if groupWithDetails.userRole == .admin {
                            Text("ADMIN")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.2, green: 0.7, blue: 0.9))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let description = groupWithDetails.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Stats row
            HStack(spacing: 0) {
                GroupStatItem(
                    icon: "person.2.fill",
                    value: "\(groupWithDetails.memberCount)",
                    label: groupWithDetails.memberCount == 1 ? "Member" : "Members"
                )
                
                Spacer()
                
                GroupStatItem(
                    icon: groupWithDetails.leaderboardResetPeriod.icon,
                    value: groupWithDetails.leaderboardResetPeriod.displayName,
                    label: "Resets"
                )
                
                Spacer()
                
                if let rank = groupWithDetails.userRank {
                    GroupStatItem(
                        icon: "trophy.fill",
                        value: "#\(rank)",
                        label: "Your Rank"
                    )
                } else {
                    GroupStatItem(
                        icon: "trophy.fill",
                        value: "--",
                        label: "Your Rank"
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Groups Header (unchanged)

struct GroupsHeader: View {
    let onCreateGroup: () -> Void
    let onJoinGroup: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Groups")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Compete with friends")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCreateGroup) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Create")
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
                
                Button(action: onJoinGroup) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                        Text("Join")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.2, green: 0.7, blue: 0.9), lineWidth: 2)
                            .background(Color.white.opacity(0.8))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Group Stat Item (unchanged)

struct GroupStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty Groups View (unchanged)

struct EmptyGroupsView: View {
    let onCreateGroup: () -> Void
    let onJoinGroup: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("No Groups Yet")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Create a group or join one with\nan invite code to start competing!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: onCreateGroup) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Create Your First Group")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3), radius: 12, x: 0, y: 6)
                }
                
                Button(action: onJoinGroup) {
                    Text("or join with invite code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 0.2, green: 0.7, blue: 0.9), lineWidth: 2)
                                .background(Color.white.opacity(0.8))
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}
