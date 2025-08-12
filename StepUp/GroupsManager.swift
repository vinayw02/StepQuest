// GroupsManager.swift - FIXED VERSION

import Foundation
import Supabase
import MessageUI
import UIKit

@MainActor
class GroupsManager: ObservableObject {
    @Published var userGroups: [GroupWithDetails] = []
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var showAlert = false
    
    private let supabase = SupabaseManager.shared.client
    
    init() {
        Task {
            await loadUserGroups()
        }
    }
    
    // MARK: - Load User Groups (FIXED)
    
    func loadUserGroups() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Loading groups for user: \(userId)")
            
            // Use simple query since the RPC function may not exist yet
            await loadUserGroupsSimple()
            
        } catch {
            print("❌ Error loading groups: \(error)")
            self.isLoading = false
            self.alertMessage = "Failed to load groups: \(error.localizedDescription)"
            self.showAlert = true
        }
    }
    
    // FIXED: Simple fallback method
    private func loadUserGroupsSimple() async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Using simple query fallback...")
            
            // Get user's memberships
            let memberships: [GroupMembership] = try await supabase
                .from("group_memberships")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if memberships.isEmpty {
                self.userGroups = []
                self.isLoading = false
                print("✅ No groups found")
                return
            }
            
            let groupIds = memberships.map { $0.groupId }
            
            // Get group details
            let groups: [Group] = try await supabase
                .from("groups")
                .select("*")
                .in("id", values: groupIds)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Combine groups with membership details
            let groupsWithDetails = groups.compactMap { group -> GroupWithDetails? in
                guard let membership = memberships.first(where: { $0.groupId == group.id }) else {
                    return nil
                }
                
                return GroupWithDetails(
                    id: group.id,
                    name: group.name,
                    description: group.description,
                    createdBy: group.createdBy,
                    leaderboardResetPeriod: group.leaderboardResetPeriod,
                    inviteCode: group.inviteCode,
                    isActive: group.isActive,
                    memberCount: group.memberCount,
                    createdAt: group.createdAt,
                    updatedAt: group.updatedAt,
                    userRole: membership.role,
                    userRank: nil // We'll load this separately if needed
                )
            }
            
            self.userGroups = groupsWithDetails
            self.isLoading = false
            print("✅ Loaded \(groupsWithDetails.count) groups (simple method)")
            
        } catch {
            print("❌ Error in simple query: \(error)")
            self.isLoading = false
            self.alertMessage = "Failed to load groups: \(error.localizedDescription)"
            self.showAlert = true
        }
    }
    
    // MARK: - Create Group
    
    func createGroup(name: String, description: String?, resetPeriod: LeaderboardResetPeriod) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Creating group: \(name)")
            
            // FIXED: Use the proper function that exists in your database
            let groupId: UUID = try await supabase
                .rpc("create_group_with_admin", params: [
                    "p_name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "p_description": description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    "p_created_by": userId.uuidString,
                    "p_leaderboard_reset_period": resetPeriod.rawValue
                ])
                .execute()
                .value
            
            self.alertMessage = "Group '\(name)' created successfully!"
            self.showAlert = true
            
            await loadUserGroups()
            
            print("✅ Group created successfully with ID: \(groupId)")
            return true
            
        } catch {
            print("❌ Error creating group: \(error)")
            self.alertMessage = "Failed to create group: \(error.localizedDescription)"
            self.showAlert = true
            return false
        }
    }
    
    // MARK: - Join Group by Invite Code
    
    func joinGroupByInviteCode(_ inviteCode: String) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Joining group with invite code: \(inviteCode)")
            
            let groupId: UUID = try await supabase
                .rpc("join_group_by_invite_code", params: [
                    "p_user_id": userId.uuidString,
                    "p_invite_code": inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                ])
                .execute()
                .value
            
            self.alertMessage = "Successfully joined group!"
            self.showAlert = true
            
            await loadUserGroups()
            
            print("✅ Joined group successfully: \(groupId)")
            return true
            
        } catch {
            print("❌ Error joining group: \(error)")
            if error.localizedDescription.contains("already a member") {
                self.alertMessage = "You're already a member of this group"
            } else if error.localizedDescription.contains("Invalid invite code") {
                self.alertMessage = "Invalid invite code or group is inactive"
            } else {
                self.alertMessage = "Failed to join group: \(error.localizedDescription)"
            }
            self.showAlert = true
            return false
        }
    }
    
    // MARK: - Get Group Leaderboard (FIXED)
    
    // Add this function to your GroupsManager.swift file
    // Replace the existing getGroupLeaderboard function with this:

    // FIXED GroupsManager.swift - getGroupLeaderboard function
    // Replace the existing getGroupLeaderboard function with this corrected version

    func getGroupLeaderboard(groupId: UUID) async -> [GroupLeaderboardEntry] {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id

            print("🔄 Loading leaderboard for group: \(groupId)")

            // Get the group's reset period first
            let groupDetails: [Group] = try await supabase
                .from("groups")
                .select("id, name, leaderboard_reset_period, created_by, description, invite_code, is_active, member_count, created_at, updated_at")
                .eq("id", value: groupId)
                .execute()
                .value

            guard let group = groupDetails.first else {
                print("❌ Group not found: \(groupId)")
                return []
            }

            print("📅 Group reset period: \(group.leaderboardResetPeriod.rawValue)")

            // Calculate date range
            let (periodStart, periodEnd) = calculatePeriodDates(for: group.leaderboardResetPeriod)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            let startDateString = formatter.string(from: periodStart)
            let endDateString = formatter.string(from: periodEnd)

            print("🔄 Using date range: \(startDateString) to \(endDateString)")

            do {
                // Execute the RPC and get raw response
                let rawResponse = try await supabase
                    .rpc("calculate_group_leaderboard", params: [
                        "p_group_id": groupId.uuidString,
                        "p_period_start": startDateString,
                        "p_period_end": endDateString
                    ])
                    .execute()

                // Deserialize raw JSON rows
                let rows = try JSONSerialization.jsonObject(with: rawResponse.data) as? [[String: Any]] ?? []

                print("🟢 Raw rows from RPC: \(rows.count)")

                var decodedRows: [GroupLeaderboardRPCResponse] = []

                for (index, dict) in rows.enumerated() {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dict)
                        let entry = try JSONDecoder().decode(GroupLeaderboardRPCResponse.self, from: jsonData)
                        decodedRows.append(entry)
                    } catch {
                        print("❌ Failed decoding row \(index): \(error)")
                        print("👉 Raw row \(index): \(dict)")
                    }
                }

                let entries = decodedRows.map { response in
                    GroupLeaderboardEntry(
                        id: response.userId,
                        userId: response.userId,
                        username: response.username,
                        avatarUrl: response.avatarUrl,
                        totalSteps: response.totalSteps,
                        rank: response.rank,
                        isCurrentUser: response.userId == currentUserId
                    )
                }

                print("✅ Loaded \(entries.count) leaderboard entries via RPC")
                return entries
            } catch {
                print("⚠️ RPC failed, trying fallback approach: \(error)")

                // Fallback: Manual calculation with correct dates
                return await getGroupLeaderboardFallback(
                    groupId: groupId,
                    currentUserId: currentUserId,
                    periodStart: periodStart,
                    periodEnd: periodEnd
                )
            }
        } catch {
            print("❌ Error in getGroupLeaderboard: \(error)")
            return []
        }
    }


    // FIXED: Helper function to calculate correct period dates based on reset type
    private func calculatePeriodDates(for resetPeriod: LeaderboardResetPeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let today = Date()
        
        switch resetPeriod {
        case .daily:
            return (today, today)
            
        case .weekly:
            // FIXED: For weekly groups created on a specific day, use that as the week start
            // Since your group was created "yesterday" (July 7th) with July 6-12 period,
            // we need to calculate the current week that contains today
            
            // Find the most recent Sunday (week start)
            let weekday = calendar.component(.weekday, from: today)
            let daysFromSunday = weekday - 1 // Sunday = 1, so Sunday = 0 days back
            
            let startOfWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) ?? today
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today
            
            return (startOfWeek, endOfWeek)
            
        case .biweekly:
            // Calculate 2-week periods
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let twoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? startOfWeek
            let endOfPeriod = calendar.date(byAdding: .day, value: 13, to: twoWeeksAgo) ?? today
            
            return (twoWeeksAgo, endOfPeriod)
            
        case .monthly:
            let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
            
            return (startOfMonth, endOfMonth)
        }
    }

    // FIXED: Fallback method with correct date parameters
    private func getGroupLeaderboardFallback(
        groupId: UUID,
        currentUserId: UUID,
        periodStart: Date,
        periodEnd: Date
    ) async -> [GroupLeaderboardEntry] {
        do {
            print("🔄 Using fallback leaderboard calculation...")
            
            // Get group members
            let memberships: [GroupMembership] = try await supabase
                .from("group_memberships")
                .select("user_id")
                .eq("group_id", value: groupId)
                .execute()
                .value
            
            let memberIds = memberships.map { $0.userId }
            print("📊 Found \(memberIds.count) group members: \(memberIds)")
            
            if memberIds.isEmpty {
                return []
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            print("📅 Fetching steps for period: \(formatter.string(from: periodStart)) to \(formatter.string(from: periodEnd))")
            
            // Get user profiles for the members
            let profiles: [UserProfile] = try await supabase
                .from("user_profiles")
                .select("id, username, avatar_url, display_name")
                .in("id", values: memberIds)
                .execute()
                .value
            
            print("👥 Found \(profiles.count) user profiles")
            
            // Get step counts for each member for the correct period
            var memberSteps: [UUID: Int] = [:]
            
            for memberId in memberIds {
                do {
                    let steps: [DailySteps] = try await supabase
                        .from("daily_steps")
                        .select("steps, date")
                        .eq("user_id", value: memberId)
                        .gte("date", value: formatter.string(from: periodStart))
                        .lte("date", value: formatter.string(from: periodEnd))
                        .execute()
                        .value
                    
                    let totalSteps = steps.reduce(0) { $0 + $1.steps }
                    memberSteps[memberId] = totalSteps
                    
                    print("👤 User \(memberId): \(totalSteps) steps across \(steps.count) days")
                    for step in steps {
                        print("   📅 \(step.date): \(step.steps) steps")
                    }
                    
                } catch {
                    print("⚠️ Could not get steps for user \(memberId): \(error)")
                    memberSteps[memberId] = 0
                }
            }
            
            // Create leaderboard entries and sort by steps
            let unsortedEntries = profiles.compactMap { profile -> GroupLeaderboardEntry? in
                let steps = memberSteps[profile.id] ?? 0
                return GroupLeaderboardEntry(
                    id: profile.id,
                    userId: profile.id,
                    username: profile.username,
                    avatarUrl: profile.avatarUrl,
                    totalSteps: steps,
                    rank: 0, // Will be set below
                    isCurrentUser: profile.id == currentUserId
                )
            }
            
            // Sort by steps (descending) and assign ranks
            let sortedEntries = unsortedEntries.sorted { $0.totalSteps > $1.totalSteps }
            let rankedEntries = sortedEntries.enumerated().map { index, entry in
                GroupLeaderboardEntry(
                    id: entry.id,
                    userId: entry.userId,
                    username: entry.username,
                    avatarUrl: entry.avatarUrl,
                    totalSteps: entry.totalSteps,
                    rank: index + 1,
                    isCurrentUser: entry.isCurrentUser
                )
            }
            
            print("✅ Fallback calculation complete: \(rankedEntries.count) entries")
            for entry in rankedEntries {
                print("   #\(entry.rank): \(entry.username) - \(entry.totalSteps) steps")
            }
            
            return rankedEntries
            
        } catch {
            print("❌ Error in fallback calculation: \(error)")
            return []
        }
    }


    // Helper struct for RPC response
    struct GroupLeaderboardRPCResponse: Codable {
        let userId: UUID
        let username: String
        let avatarUrl: String?
        let totalSteps: Int
        let rank: Int
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case username
            case avatarUrl = "avatar_url"
            case totalSteps = "total_steps"
            case rank
        }
    }
    
    // MARK: - Share Group Invite Link
    
    func shareGroupInviteLink(group: Group) {
        let inviteText = "Join my StepQuest group '\(group.name)'! Use invite code: \(group.inviteCode)"
        let inviteUrl = "stepquest://join?code=\(group.inviteCode)"
        
        if MFMessageComposeViewController.canSendText() {
            let messageVC = MFMessageComposeViewController()
            messageVC.body = "\(inviteText)\n\nOr click this link: \(inviteUrl)"
            messageVC.messageComposeDelegate = MessageComposeDelegate.shared
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(messageVC, animated: true)
            }
        } else {
            // Fallback to activity controller
            let activityController = UIActivityViewController(
                activityItems: [inviteText, URL(string: inviteUrl)!],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                if let popover = activityController.popoverPresentationController {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                }
                
                rootViewController.present(activityController, animated: true)
            }
        }
    }
    
    // MARK: - Leave Group
    
    func leaveGroup(groupId: UUID) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Leaving group: \(groupId)")
            
            try await supabase
                .from("group_memberships")
                .delete()
                .eq("group_id", value: groupId)
                .eq("user_id", value: userId)
                .execute()
            
            self.alertMessage = "Left group successfully"
            self.showAlert = true
            
            await loadUserGroups()
            
            print("✅ Left group successfully")
            return true
            
        } catch {
            print("❌ Error leaving group: \(error)")
            self.alertMessage = "Failed to leave group: \(error.localizedDescription)"
            self.showAlert = true
            return false
        }
    }
    
    // MARK: - Invite Friends to Group
    
    func inviteFriendsToGroup(groupId: UUID, friendIds: [UUID]) async -> Bool {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Inviting \(friendIds.count) friends to group: \(groupId)")
            
            // Check if current user is admin of the group
            let membership: [GroupMembership] = try await supabase
                .from("group_memberships")
                .select("*")
                .eq("group_id", value: groupId)
                .eq("user_id", value: userId)
                .eq("role", value: "admin")
                .execute()
                .value
            
            guard !membership.isEmpty else {
                self.alertMessage = "Only group admins can invite friends"
                self.showAlert = true
                return false
            }
            
            // Add each friend to the group
            var successCount = 0
            for friendId in friendIds {
                do {
                    // Check if friend is already a member
                    let existingMembership: [GroupMembership] = try await supabase
                        .from("group_memberships")
                        .select("*")
                        .eq("group_id", value: groupId)
                        .eq("user_id", value: friendId)
                        .execute()
                        .value
                    
                    if existingMembership.isEmpty {
                        // Add friend as member
                        try await supabase
                            .from("group_memberships")
                            .insert([
                                "group_id": groupId.uuidString,
                                "user_id": friendId.uuidString,
                                "role": "member"
                            ])
                            .execute()
                        
                        successCount += 1
                    }
                } catch {
                    print("❌ Error inviting friend \(friendId): \(error)")
                }
            }
            
            if successCount > 0 {
                self.alertMessage = "Successfully invited \(successCount) friend\(successCount == 1 ? "" : "s")!"
                self.showAlert = true
                await loadUserGroups()
                return true
            } else {
                self.alertMessage = "No new friends were invited (they may already be members)"
                self.showAlert = true
                return false
            }
            
        } catch {
            print("❌ Error inviting friends to group: \(error)")
            self.alertMessage = "Failed to invite friends: \(error.localizedDescription)"
            self.showAlert = true
            return false
        }
    }
}

// MARK: - Message Compose Delegate

class MessageComposeDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static let shared = MessageComposeDelegate()
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
        
        switch result {
        case .sent:
            print("✅ Invite message sent")
        case .cancelled:
            print("📱 Message cancelled")
        case .failed:
            print("❌ Message failed to send")
        @unknown default:
            break
        }
    }
}
