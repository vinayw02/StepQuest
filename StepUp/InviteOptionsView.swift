// InviteOptionsView.swift - COMPLETELY FIXED VERSION

import SwiftUI
import MessageUI

struct InviteOptionsView: View {
    let group: GroupWithDetails
    let groupsManager: GroupsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showFriendsList = false
    @State private var selectedFriends: Set<UUID> = []
    @State private var friends: [FriendData] = []
    @State private var isLoadingFriends = false
    @State private var showingMessageComposer = false
    @State private var showingShareSheet = false
    @State private var copySuccessMessage = ""
    
    // Access supabase through SupabaseManager
    private var supabase = SupabaseManager.shared.client
    
    // EXPLICIT INIT: Ensures accessibility
    init(group: GroupWithDetails, groupsManager: GroupsManager) {
        self.group = group
        self.groupsManager = groupsManager
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Blue Premium background
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Invite to Group")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Invite friends to join '\(group.name)'")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Invite Code Section
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Text("Share Invite Code")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Share this code with friends to let them join your group")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Invite code display
                        VStack(spacing: 16) {
                            Text(group.inviteCode)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), lineWidth: 2)
                                        )
                                )
                            
                            Button(action: copyInviteCode) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 16, weight: .medium))
                                    Text(copySuccessMessage.isEmpty ? "Copy Code" : copySuccessMessage)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(copySuccessMessage.isEmpty ? Color(red: 0.2, green: 0.7, blue: 0.9) : .green)
                                )
                            }
                        }
                    }
                    
                    // Or divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    
                    // Invite options
                    VStack(spacing: 16) {
                        InviteOptionButton(
                            icon: "message",
                            title: "Send Text Message",
                            subtitle: "Share via SMS or messaging app"
                        ) {
                            print("🔄 Text message button tapped")
                            sendTextMessage()
                        }
                        
                        InviteOptionButton(
                            icon: "square.and.arrow.up",
                            title: "Share Invite Link",
                            subtitle: "Share via any app or social media"
                        ) {
                            print("🔄 Share button tapped")
                            shareInviteCode()
                        }
                        /*
                        InviteOptionButton(
                            icon: "person.2.fill",
                            title: "Invite Friends",
                            subtitle: "Select from your StepUp friends"
                        )
                         {
                            print("🔄 Invite friends button tapped")
                            loadFriends()
                            showFriendsList = true
                        }
                         */
                    }
                         
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .overlay(
            VStack {
                HStack {
                    Button("Done") {
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
        .sheet(isPresented: $showFriendsList) {
            FriendsListView(
                selectedFriends: $selectedFriends,
                friends: friends,
                isLoading: isLoadingFriends,
                onInvite: inviteSelectedFriends
            )
        }
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposeView(
                recipients: [],
                body: createInviteMessage(),
                onDismiss: {
                    showingMessageComposer = false
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [createInviteMessage()])
        }
    }
    
    // MARK: - Private Methods
    
    private func copyInviteCode() {
        print("🔄 Copy button tapped")
        UIPasteboard.general.string = group.inviteCode
        copySuccessMessage = "Copied!"
        
        // Reset message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copySuccessMessage = ""
        }
        
        print("📋 Invite code copied to clipboard: \(group.inviteCode)")
    }
    
    private func createInviteMessage() -> String {
        return "Join my StepUp group '\(group.name)'! Use invite code: \(group.inviteCode)"
    }
    
    private func sendTextMessage() {
        guard MFMessageComposeViewController.canSendText() else {
            print("❌ Cannot send text messages on this device")
            // Fallback to share sheet
            shareInviteCode()
            return
        }
        
        // Dismiss any existing sheets first
        if showFriendsList {
            showFriendsList = false
        }
        
        // Wait a bit then show message composer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingMessageComposer = true
        }
    }
    
    private func shareInviteCode() {
        // Dismiss any existing sheets first
        if showFriendsList {
            showFriendsList = false
        }
        
        // Wait a bit then show share sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingShareSheet = true
        }
    }
    
    private func loadFriends() {
        print("🔄 Loading friends...")
        isLoadingFriends = true
        
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                print("📱 User ID: \(userId)")
                
                // FIXED QUERY: Simplified to avoid relationship issues
                let friendships: [SimpleFriendship] = try await supabase
                    .from("friendships")
                    .select("friend_id")
                    .eq("user_id", value: userId)
                    .eq("status", value: "accepted")
                    .execute()
                    .value
                
                print("📊 Found \(friendships.count) friendships")
                
                // Get friend profiles separately
                let friendIds = friendships.map { $0.friendId }
                
                if friendIds.isEmpty {
                    await MainActor.run {
                        self.friends = []
                        self.isLoadingFriends = false
                    }
                    return
                }
                
                let profiles: [UserProfile] = try await supabase
                    .from("user_profiles")
                    .select("id, username, display_name, avatar_url")
                    .in("id", values: friendIds)
                    .execute()
                    .value
                
                // Get user stats separately
                let userStats: [SimpleUserStats] = try await supabase
                    .from("user_stats")
                    .select("user_id, current_tier_id, total_points")
                    .in("user_id", values: friendIds)
                    .execute()
                    .value
                
                // Combine the data
                let friendsData: [FriendData] = profiles.compactMap { profile in
                    let stats = userStats.first { $0.userId == profile.id }
                    
                    return FriendData(
                        id: profile.id,
                        username: profile.username,
                        displayName: profile.displayName ?? profile.username,
                        tier: globalTierList.first { $0.id == (stats?.currentTierId ?? 1) } ?? globalTierList[0],
                        totalPoints: stats?.totalPoints ?? 0
                    )
                }
                
                print("✅ Loaded \(friendsData.count) friends")
                
                await MainActor.run {
                    self.friends = friendsData
                    self.isLoadingFriends = false
                }
                
            } catch {
                print("❌ Error loading friends: \(error)")
                await MainActor.run {
                    self.friends = []
                    self.isLoadingFriends = false
                }
            }
        }
    }
    
    private func inviteSelectedFriends() {
        print("🔄 Inviting selected friends...")
        Task {
            let friendIds = Array(selectedFriends)
            print("📱 Inviting \(friendIds.count) friends")
            let success = await groupsManager.inviteFriendsToGroup(groupId: group.id, friendIds: friendIds)
            
            await MainActor.run {
                if success {
                    selectedFriends.removeAll()
                    showFriendsList = false
                    print("✅ Successfully invited friends")
                } else {
                    print("❌ Failed to invite friends")
                }
            }
        }
    }
}

// MARK: - Supporting Data Models

struct SimpleFriendship: Codable {
    let friendId: UUID
    
    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
    }
}

struct SimpleUserStats: Codable {
    let userId: UUID
    let currentTierId: Int?
    let totalPoints: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case currentTierId = "current_tier_id"
        case totalPoints = "total_points"
    }
}

// MARK: - Supporting Views

struct InviteOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            print("🔄 Button tapped: \(title)")
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let messageVC = MFMessageComposeViewController()
        messageVC.recipients = recipients
        messageVC.body = body
        messageVC.messageComposeDelegate = context.coordinator
        return messageVC
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
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
            onDismiss()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FriendsListView: View {
    @Binding var selectedFriends: Set<UUID>
    let friends: [FriendData]
    let isLoading: Bool
    let onInvite: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading friends...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Friends Yet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Add friends from the Friends tab to invite them to groups")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(friends) { friend in
                            FriendRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                onToggle: {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.remove(friend.id)
                                    } else {
                                        selectedFriends.insert(friend.id)
                                    }
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invite") {
                        onInvite()
                    }
                    .disabled(selectedFriends.isEmpty)
                }
            }
        }
    }
}

struct FriendRow: View {
    let friend: FriendData
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Avatar placeholder
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(friend.username.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading) {
                    Text(friend.username)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
