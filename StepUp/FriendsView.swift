// CLEAN FITNESS APP FRIENDSVIEW - FIXED SEARCH & TABS
import SwiftUI
import Supabase

struct FriendsView: View {
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var friends: [FriendData] = []
    @State private var searchResults: [UserSearchResult] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var sentRequests: [SentRequest] = []
    @State private var isLoading = false
    @State private var isSearching = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var animateCards = false
    
    private let tabs = ["Friends", "Requests"]
    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean background
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.98, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Friends")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
                    
                    // Tab Selector
                    TabSelector(
                        tabs: tabs,
                        selectedTab: $selectedTab
                    )
                    .padding(.top, 20)
                    
                    // Search Bar (only show on Friends tab)
                    if selectedTab == 0 {
                        SearchBar(
                            searchText: $searchText,
                            isSearching: $isSearching,
                            onSearchChanged: performSearch
                        )
                        .padding(.top, 16)
                    }
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 20) {
                                if selectedTab == 0 {
                                    // Friends Tab
                                    if !searchText.isEmpty {
                                        // Search Results
                                        if !searchResults.isEmpty {
                                            SearchResultsSection(
                                                results: searchResults,
                                                onAddFriend: sendFriendRequest
                                            )
                                        } else if !isSearching {
                                            Text("No users found")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 40)
                                        }
                                    } else {
                                        // Friends List
                                        if !friends.isEmpty {
                                            FriendsGrid(friends: friends, animateCards: animateCards)
                                        } else {
                                            EmptyFriendsState()
                                        }
                                    }
                                } else {
                                    // Requests Tab
                                    VStack(spacing: 20) {
                                        if !pendingRequests.isEmpty {
                                            PendingRequestsSection(
                                                requests: pendingRequests,
                                                onAccept: acceptFriendRequest,
                                                onDecline: declineFriendRequest
                                            )
                                        }
                                        
                                        if !sentRequests.isEmpty {
                                            SentRequestsSection(
                                                requests: sentRequests,
                                                onCancel: cancelSentRequest
                                            )
                                        }
                                        
                                        if pendingRequests.isEmpty && sentRequests.isEmpty {
                                            EmptyRequestsState()
                                        }
                                    }
                                }
                                
                                Spacer(minLength: 80)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadAllData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animateCards = true
            }
        }
        .alert("Friends", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadAllData() {
        isLoading = true
        Task {
            await fetchFriends()
            await fetchPendingRequests()
            await fetchSentRequests()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func performSearch() {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedSearch.isEmpty else {
            searchResults = []
            return
        }
        
        guard trimmedSearch.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        Task {
            await searchUsers(query: trimmedSearch)
            await MainActor.run {
                isSearching = false
            }
        }
    }
    
    private func fetchFriends() async {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Get accepted friendships where current user is either user_id OR friend_id
            struct SimpleFriendship: Codable {
                let user_id: UUID
                let friend_id: UUID
            }
            
            let friendships: [SimpleFriendship] = try await supabase
                .from("friendships")
                .select("user_id, friend_id")
                .eq("status", value: "accepted")
                .or("user_id.eq.\(currentUserId),friend_id.eq.\(currentUserId)")
                .execute()
                .value
            
            if friendships.isEmpty {
                await MainActor.run {
                    self.friends = []
                }
                return
            }
            
            // Extract friend IDs (the other person in each friendship)
            let friendIds = friendships.compactMap { friendship -> UUID? in
                if friendship.user_id == currentUserId {
                    return friendship.friend_id
                } else if friendship.friend_id == currentUserId {
                    return friendship.user_id
                } else {
                    return nil
                }
            }
            
            if friendIds.isEmpty {
                await MainActor.run {
                    self.friends = []
                }
                return
            }
            
            let profiles: [UserSearchProfile] = try await supabase
                .from("user_profiles")
                .select("id, username, display_name")
                .in("id", values: friendIds)
                .execute()
                .value
            
            let friendsData = profiles.map { profile -> FriendData in
                return FriendData(
                    id: profile.id,
                    username: profile.username,
                    displayName: profile.displayName ?? profile.username,
                    tier: globalTierList[0],
                    totalPoints: 0
                )
            }
            
            await MainActor.run {
                self.friends = friendsData.sorted { $0.username < $1.username }
            }
            
        } catch {
            print("❌ Error fetching friends: \(error)")
        }
    }
    
    private func fetchPendingRequests() async {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Get pending requests WHERE current user is the friend_id (receiving requests)
            let requests: [FriendshipWithProfile] = try await supabase
                .from("friendships")
                .select("user_id, requested_by, user_profiles!friendships_user_id_fkey(username, display_name)")
                .eq("friend_id", value: currentUserId)
                .eq("status", value: "pending")
                .execute()
                .value
            
            let pendingData = requests.compactMap { request -> FriendRequest? in
                guard let profile = request.userProfiles else { return nil }
                
                return FriendRequest(
                    id: UUID(),
                    fromUserId: request.userId,
                    username: profile.username,
                    displayName: profile.displayName ?? profile.username
                )
            }
            
            await MainActor.run {
                self.pendingRequests = pendingData
            }
            
        } catch {
            print("Error fetching pending requests: \(error)")
        }
    }
    
    private func fetchSentRequests() async {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Get pending requests WHERE current user is the user_id (sent requests)
            let requests: [FriendshipWithProfile] = try await supabase
                .from("friendships")
                .select("user_id, friend_id, requested_by, user_profiles!friendships_friend_id_fkey(username, display_name)")  // ← Added user_id
                .eq("user_id", value: currentUserId)
                .eq("status", value: "pending")
                .execute()
                .value
            
            let sentData = requests.compactMap { request -> SentRequest? in
                guard let profile = request.userProfiles else { return nil }
                
                return SentRequest(
                    id: UUID(),
                    toUserId: request.friendId,
                    username: profile.username,
                    displayName: profile.displayName ?? profile.username
                )
            }
            
            await MainActor.run {
                self.sentRequests = sentData
            }
            
        } catch {
            print("Error fetching sent requests: \(error)")
        }
    }
    
    private func searchUsers(query: String) async {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            print("🔍 Searching for: '\(query)'")
            
            let users: [UserSearchProfile] = try await supabase
                .from("user_profiles")
                .select("id, username, display_name")
                .ilike("username", value: "%\(query)%")
                .neq("id", value: currentUserId)
                .limit(20)
                .execute()
                .value
            
            print("🔍 Found \(users.count) users")
            
            // Filter out existing friends and pending requests
            let friendIds = Set(friends.map { $0.id })
            let pendingIds = Set(pendingRequests.map { $0.fromUserId })
            let sentIds = Set(sentRequests.map { $0.toUserId })
            
            let filteredUsers = users.filter { user in
                !friendIds.contains(user.id) &&
                !pendingIds.contains(user.id) &&
                !sentIds.contains(user.id)
            }
            
            print("🔍 After filtering: \(filteredUsers.count) users")
            
            let searchResults = filteredUsers.map { user in
                UserSearchResult(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName ?? user.username
                )
            }
            
            await MainActor.run {
                self.searchResults = searchResults
            }
            
        } catch {
            print("❌ Error searching users: \(error)")
            await MainActor.run {
                self.searchResults = []
            }
        }
    }
    
    private func sendFriendRequest(to user: UserSearchResult) {
        Task {
            do {
                let session = try await supabase.auth.session
                let currentUserId = session.user.id
                
                print("📤 Sending friend request to: \(user.username)")
                
                let friendship = FriendshipInsert(
                    userId: currentUserId,
                    friendId: user.id,
                    status: "pending",
                    requestedBy: currentUserId
                )
                
                try await supabase
                    .from("friendships")
                    .insert(friendship)
                    .execute()
                
                print("✅ Friend request sent successfully")
                
                await MainActor.run {
                    // Remove from search results
                    searchResults.removeAll { $0.id == user.id }
                    alertMessage = "Friend request sent to \(user.username)!"
                    showAlert = true
                }
                
                // Refresh sent requests
                await fetchSentRequests()
                
            } catch {
                print("❌ Error sending friend request: \(error)")
                await MainActor.run {
                    alertMessage = "Failed to send friend request"
                    showAlert = true
                }
            }
        }
    }
    
    private func acceptFriendRequest(_ request: FriendRequest) {
        Task {
            do {
                let session = try await supabase.auth.session
                let currentUserId = session.user.id
                
                print("✅ Accepting friend request from: \(request.username)")
                
                // Simply update the existing friendship status to accepted
                // NO reciprocal friendship needed - one record handles both directions
                try await supabase
                    .from("friendships")
                    .update(["status": "accepted"])
                    .eq("user_id", value: request.fromUserId)
                    .eq("friend_id", value: currentUserId)
                    .eq("status", value: "pending")
                    .execute()
                
                print("✅ Friendship accepted successfully")
                
                await MainActor.run {
                    pendingRequests.removeAll { $0.id == request.id }
                    alertMessage = "You're now friends with \(request.username)!"
                    showAlert = true
                }
                
                // Refresh friends list
                await fetchFriends()
                
            } catch {
                print("❌ Error accepting friend request: \(error)")
                await MainActor.run {
                    alertMessage = "Failed to accept friend request"
                    showAlert = true
                }
            }
        }
    }
    
    private func declineFriendRequest(_ request: FriendRequest) {
        Task {
            do {
                let session = try await supabase.auth.session
                let currentUserId = session.user.id
                
                print("❌ Declining friend request from: \(request.username)")
                
                // Delete the friendship request
                try await supabase
                    .from("friendships")
                    .delete()
                    .eq("user_id", value: request.fromUserId)
                    .eq("friend_id", value: currentUserId)
                    .execute()
                
                print("✅ Friend request declined successfully")
                
                await MainActor.run {
                    pendingRequests.removeAll { $0.id == request.id }
                }
                
            } catch {
                print("❌ Error declining friend request: \(error)")
                await MainActor.run {
                    alertMessage = "Failed to decline friend request"
                    showAlert = true
                }
            }
        }
    }
    
    private func cancelSentRequest(_ request: SentRequest) {
        Task {
            do {
                let session = try await supabase.auth.session
                let currentUserId = session.user.id
                
                print("🚫 Canceling sent request to: \(request.username)")
                
                // Delete the sent friendship request
                try await supabase
                    .from("friendships")
                    .delete()
                    .eq("user_id", value: currentUserId)
                    .eq("friend_id", value: request.toUserId)
                    .execute()
                
                print("✅ Sent request canceled successfully")
                
                await MainActor.run {
                    sentRequests.removeAll { $0.id == request.id }
                }
                
            } catch {
                print("❌ Error canceling sent request: \(error)")
                await MainActor.run {
                    alertMessage = "Failed to cancel request"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - UI COMPONENTS

struct TabSelector: View {
    let tabs: [String]
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                }) {
                    Text(tab)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selectedTab == index ? .white : Color(red: 0.2, green: 0.7, blue: 0.9))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == index ? Color(red: 0.2, green: 0.7, blue: 0.9) : Color.clear)
                        )
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct SearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    let onSearchChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            
            TextField("Search username...", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .onChange(of: searchText) { _ in
                    onSearchChanged()
                }
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.2, green: 0.7, blue: 0.9)))
            } else if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onSearchChanged()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
}

struct FriendsGrid: View {
    let friends: [FriendData]
    let animateCards: Bool
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends (\(friends.count))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                    CompactFriendCard(friend: friend)
                        .scaleEffect(animateCards ? 1.0 : 0.8)
                        .opacity(animateCards ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: animateCards
                        )
                }
            }
        }
    }
}

struct CompactFriendCard: View {
    let friend: FriendData
    
    var body: some View {
        VStack(spacing: 8) {
            // Profile picture
            Circle()
                .fill(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(friend.username.prefix(1).uppercased()))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                )
            
            // Username
            Text("@\(friend.username)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct SearchResultsSection: View {
    let results: [UserSearchResult]
    let onAddFriend: (UserSearchResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results (\(results.count))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            ForEach(results) { user in
                SearchResultCard(user: user, onAddFriend: onAddFriend)
            }
        }
    }
}

struct SearchResultCard: View {
    let user: UserSearchResult
    let onAddFriend: (UserSearchResult) -> Void
    @State private var isAdding = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.username.prefix(1).uppercased()))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                )
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("@\(user.username)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Add button
            Button(action: {
                isAdding = true
                onAddFriend(user)
            }) {
                Text(isAdding ? "Sending..." : "Add")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.9))
                    )
            }
            .disabled(isAdding)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct PendingRequestsSection: View {
    let requests: [FriendRequest]
    let onAccept: (FriendRequest) -> Void
    let onDecline: (FriendRequest) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Incoming Requests (\(requests.count))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            ForEach(requests) { request in
                PendingRequestCard(
                    request: request,
                    onAccept: onAccept,
                    onDecline: onDecline
                )
            }
        }
    }
}

struct PendingRequestCard: View {
    let request: FriendRequest
    let onAccept: (FriendRequest) -> Void
    let onDecline: (FriendRequest) -> Void
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(request.username.prefix(1).uppercased()))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                )
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("@\(request.username)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    isProcessing = true
                    onDecline(request)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.1))
                        )
                }
                
                Button(action: {
                    isProcessing = true
                    onAccept(request)
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(red: 0.2, green: 0.7, blue: 0.9))
                        )
                }
            }
            .disabled(isProcessing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SentRequestsSection: View {
    let requests: [SentRequest]
    let onCancel: (SentRequest) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sent Requests (\(requests.count))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            ForEach(requests) { request in
                SentRequestCard(request: request, onCancel: onCancel)
            }
        }
    }
}

struct SentRequestCard: View {
    let request: SentRequest
    let onCancel: (SentRequest) -> Void
    @State private var isCanceling = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(request.username.prefix(1).uppercased()))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                )
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("@\(request.username)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Pending")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
            
            // Cancel button
            Button(action: {
                isCanceling = true
                onCancel(request)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.1))
                    )
            }
            .disabled(isCanceling)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EmptyFriendsState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No friends yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Search above to find friends")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }
}

struct EmptyRequestsState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No friend requests")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Friend requests will appear here")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }
}

// MARK: - DATA MODELS

struct FriendData: Identifiable {
    let id: UUID
    let username: String
    let displayName: String
    let tier: Tier
    let totalPoints: Int
}

struct UserSearchResult: Identifiable {
    let id: UUID
    let username: String
    let displayName: String
}

struct FriendRequest: Identifiable {
    let id: UUID
    let fromUserId: UUID
    let username: String
    let displayName: String
}

struct SentRequest: Identifiable {
    let id: UUID
    let toUserId: UUID
    let username: String
    let displayName: String
}

struct FriendshipInsert: Codable {
    let userId: UUID
    let friendId: UUID
    let status: String
    let requestedBy: UUID
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case requestedBy = "requested_by"
    }
}

struct FriendshipWithProfile: Codable {
    let userId: UUID
    let friendId: UUID
    let userProfiles: UserSearchProfile?
    let userStats: UserStatsProfile?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case friendId = "friend_id"
        case userProfiles = "user_profiles"
        case userStats = "user_stats"
    }
}

struct UserSearchProfile: Codable {
    let id: UUID
    let username: String
    let displayName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
    }
}

struct UserStatsProfile: Codable {
    let userId: UUID
    let currentTierId: Int?
    let totalPoints: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case currentTierId = "current_tier_id"
        case totalPoints = "total_points"
    }
}
