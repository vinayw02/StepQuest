// UPDATED ProfileView.swift with Blue Theme
import SwiftUI
import PhotosUI
import Supabase

struct ProfileView: View {
    @StateObject private var profileManager = ProfileManager()
    @State private var showImagePicker = false
    @State private var showEditUsername = false
    @State private var showChangePassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSignOutConfirmation = false
    @State private var showTimezoneSelector = false
    
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
                
                if profileManager.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                        Text("Loading profile...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Profile Header
                            BlueProfileHeader(
                                profileManager: profileManager,
                                onEditPhoto: { showImagePicker = true }
                            )
                            .padding(.top, 20)
                            
                            // Steps Cards
                            BlueStepsSection(
                                todaySteps: profileManager.todaySteps,
                                weeklyAverage: profileManager.weeklyAverage
                            )
                            
                            // Ranking Cards
                            BlueRankingSection(
                                profileManager: profileManager
                            )
                            
                            // Settings Section
                            BlueSettingsSection(
                                profileManager: profileManager,
                                onEditUsername: { showEditUsername = true },
                                onChangePassword: { showChangePassword = true },
                                onTimezoneSelector: { showTimezoneSelector = true },
                                onSignOut: { showSignOutConfirmation = true }
                            )
                            
                            Spacer(minLength: 50)
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable {
                        await profileManager.loadUserProfile()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            profileManager.loadUserProfile()
        }
        .photosPicker(isPresented: $showImagePicker, selection: $profileManager.selectedPhoto, matching: .images)
        .sheet(isPresented: $showEditUsername) {
            BlueEditUsernameSheet(profileManager: profileManager)
        }
        .sheet(isPresented: $showChangePassword) {
            BlueChangePasswordSheet()
        }
        .sheet(isPresented: $showTimezoneSelector) {
            BlueTimezonePickerSheet(profileManager: profileManager)
        }
        .alert("Profile", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                profileManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onChange(of: profileManager.alertMessage) { message in
            if !message.isEmpty {
                alertMessage = message
                showAlert = true
                profileManager.alertMessage = ""
            }
        }
    }
}

// MARK: - BLUE THEMED COMPONENTS

struct BlueProfileHeader: View {
    @ObservedObject var profileManager: ProfileManager
    let onEditPhoto: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with title
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Your fitness journey")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Profile Image and Info
            VStack(spacing: 16) {
                ZStack {
                    if let profileImage = profileManager.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2), Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text(profileManager.userProfile?.username.prefix(1).uppercased() ?? "U")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                    }
                    
                    // Edit button
                    Button(action: onEditPhoto) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .offset(x: 40, y: 40)
                }
                
                // User Info
                VStack(spacing: 8) {
                    Text(profileManager.userProfile?.displayName ?? "Unknown User")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("@\(profileManager.userProfile?.username ?? "unknown")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Current Tier Badge
                    if let tier = profileManager.currentTier {
                        HStack(spacing: 8) {
                            Image(systemName: tier.icon ?? "star.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                            
                            Text(tier.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                }
            }
        }
    }
}

struct BlueStepsSection: View {
    let todaySteps: Int
    let weeklyAverage: Int
    @State private var databaseWeeklyAverage: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Steps")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                BlueStepsCard(
                    title: "Today",
                    value: "\(formatNumber(todaySteps))",
                    icon: "figure.walk",
                    gradientColors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)]
                )
                
                BlueStepsCard(
                    title: "Weekly Avg",
                    value: "\(formatNumber(databaseWeeklyAverage))",  // CHANGED: Use database value
                    icon: "calendar.badge.clock",
                    gradientColors: [Color(red: 0.3, green: 0.8, blue: 1.0), Color(red: 0.2, green: 0.7, blue: 0.9)]
                )
            }
        }
        .onAppear {
            Task {
                await fetchDatabaseWeeklyAverage()
            }
        }
    }
    
    // NEW: Function to fetch weekly average from database
    private func fetchDatabaseWeeklyAverage() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let today = DateFormatter.databaseDate.string(from: Date())
            
            let dailySteps: [DailySteps] = try await SupabaseManager.shared.client
                .from("daily_steps")
                .select("*")
                .eq("user_id", value: session.user.id)
                .eq("date", value: today)
                .execute()
                .value
            
            if let record = dailySteps.first {
                await MainActor.run {
                    let newValue = record.weeklyAverage
                    if newValue > 0 {
                        databaseWeeklyAverage = newValue
                    }
                }
            }
            
        } catch {
            print("Error fetching database weekly average in ProfileView: \(error)")
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct BlueStepsCard: View {
    let title: String
    let value: String
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct BlueRankingSection: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var userRankings: UserRankings?
    @State private var isLoadingRanks = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Rankings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if isLoadingRanks {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                    Text("Loading rankings...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(height: 200)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    BlueRankingCard(
                        title: "Daily Global",
                        rank: userRankings?.globalDaily,
                        icon: "globe",
                        gradientColors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)]
                    )
                    
                    BlueRankingCard(
                        title: "Weekly Global",
                        rank: userRankings?.globalWeekly,
                        icon: "globe.badge.chevron.backward",
                        gradientColors: [Color(red: 0.3, green: 0.8, blue: 1.0), Color(red: 0.2, green: 0.7, blue: 0.9)]
                    )
                    
                    BlueRankingCard(
                        title: "Daily Friends",
                        rank: userRankings?.friendsDaily,
                        icon: "person.2",
                        gradientColors: [Color(red: 0.1, green: 0.6, blue: 0.8), Color(red: 0.0, green: 0.5, blue: 0.7)]
                    )
                    
                    BlueRankingCard(
                        title: "Weekly Friends",
                        rank: userRankings?.friendsWeekly,
                        icon: "person.2.circle",
                        gradientColors: [Color(red: 0.4, green: 0.9, blue: 1.1), Color(red: 0.3, green: 0.8, blue: 1.0)]
                    )
                }
            }
        }
        .onAppear {
            loadUserRankings()
        }
    }
    
    private func loadUserRankings() {
        isLoadingRanks = true
        
        Task {
            do {
                let supabase = SupabaseManager.shared.client
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
                    await MainActor.run {
                        self.userRankings = UserRankings(
                            globalDaily: ranking.globalDailyRank,
                            globalWeekly: ranking.globalWeeklyRank,
                            friendsDaily: ranking.friendsDailyRank,
                            friendsWeekly: ranking.friendsWeeklyRank,
                            todaySteps: ranking.dailySteps,
                            weeklySteps: ranking.weeklySteps
                        )
                        self.isLoadingRanks = false
                    }
                } else {
                    try await supabase.rpc("update_user_steps_only", params: [
                        "target_user_id": session.user.id.uuidString,
                        "target_date": today
                    ]).execute()
                    
                    let updatedRankings: [UserRankingResponse] = try await supabase
                        .from("leaderboard_cache")
                        .select("global_daily_rank, global_weekly_rank, friends_daily_rank, friends_weekly_rank, daily_steps, weekly_steps")
                        .eq("user_id", value: session.user.id)
                        .eq("date", value: today)
                        .execute()
                        .value
                    
                    await MainActor.run {
                        if let ranking = updatedRankings.first {
                            self.userRankings = UserRankings(
                                globalDaily: ranking.globalDailyRank,
                                globalWeekly: ranking.globalWeeklyRank,
                                friendsDaily: ranking.friendsDailyRank,
                                friendsWeekly: ranking.friendsWeeklyRank,
                                todaySteps: ranking.dailySteps,
                                weeklySteps: ranking.weeklySteps
                            )
                        }
                        self.isLoadingRanks = false
                    }
                }
                
            } catch {
                print("Error loading user rankings: \(error)")
                await MainActor.run {
                    self.isLoadingRanks = false
                }
            }
        }
    }
}

struct BlueRankingCard: View {
    let title: String
    let rank: Int?
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            
            VStack(spacing: 4) {
                if let rank = rank {
                    Text("#\(rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("--")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct BlueSettingsSection: View {
    @ObservedObject var profileManager: ProfileManager
    let onEditUsername: () -> Void
    let onChangePassword: () -> Void
    let onTimezoneSelector: () -> Void
    let onSignOut: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                BlueSettingsRow(
                    icon: "person.fill",
                    title: "Edit Username",
                    action: onEditUsername
                )
                
                BlueSettingsRow(
                    icon: "lock.fill",
                    title: "Change Password",
                    action: onChangePassword
                )
                
                BlueSettingsRow(
                    icon: "globe",
                    title: "Time Zone",
                    subtitle: profileManager.userTimezone ?? TimeZone.current.localizedName(for: .standard, locale: .current) ?? "Auto",
                    action: onTimezoneSelector
                )
                
                BlueSettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    isDestructive: true,
                    action: onSignOut
                )
            }
        }
    }
}

struct BlueSettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isDestructive: Bool
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            isDestructive ?
                                Color.red.opacity(0.2) :
                                Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2)
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDestructive ? .red : Color(red: 0.2, green: 0.7, blue: 0.9))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - BLUE THEMED SHEETS

struct BlueEditUsernameSheet: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var newUsername = ""
    @State private var isLoading = false
    
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
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Edit Username")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose a new username for your profile")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Username")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        TextField("Enter new username", text: $newUsername)
                            .textFieldStyle(BlueTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button(action: updateUsername) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            Text("Update Username")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .disabled(isLoading || newUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
            }
        }
        .onAppear {
            newUsername = profileManager.userProfile?.username ?? ""
        }
    }
    
    private func updateUsername() {
        isLoading = true
        Task {
            await profileManager.updateUsername(newUsername.trimmingCharacters(in: .whitespacesAndNewlines))
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
}

struct BlueChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Change Password")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Enter your current password and choose a new one")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Enter current password", text: $currentPassword)
                                .textFieldStyle(BlueTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Enter new password", text: $newPassword)
                                .textFieldStyle(BlueTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Confirm new password", text: $confirmPassword)
                                .textFieldStyle(BlueTextFieldStyle())
                        }
                    }
                    
                    Button(action: changePassword) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            Text("Change Password")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .disabled(isLoading || !isFormValid)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
            }
        }
        .alert("Change Password", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            alertMessage = "New passwords don't match"
            showAlert = true
            return
        }
        
        guard newPassword.count >= 6 else {
            alertMessage = "Password must be at least 6 characters"
            showAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let supabase = SupabaseManager.shared.client
                try await supabase.auth.update(
                    user: UserAttributes(password: newPassword)
                )
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Password changed successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to change password: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct BlueTimezonePickerSheet: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimezone = TimeZone.current.identifier
    @State private var isLoading = false
    
    private let commonTimezones = [
        "America/New_York",
        "America/Chicago",
        "America/Denver",
        "America/Los_Angeles",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Australia/Sydney"
    ]
    
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
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text("Select Time Zone")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Your time zone is used for calculating when your day ends for point losses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    List {
                        ForEach(commonTimezones, id: \.self) { timezone in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(timezoneName(for: timezone))
                                        .font(.body)
                                    Text(timezone)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedTimezone == timezone {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTimezone = timezone
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    Button(action: updateTimezone) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            Text("Update Time Zone")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                }
            }
        }
        .onAppear {
            selectedTimezone = profileManager.userTimezone ?? TimeZone.current.identifier
        }
    }
    
    private func timezoneName(for identifier: String) -> String {
        let timezone = TimeZone(identifier: identifier)
        return timezone?.localizedName(for: .standard, locale: .current) ?? identifier
    }
    
    private func updateTimezone() {
        isLoading = true
        Task {
            await profileManager.updateTimezone(selectedTimezone)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - BLUE TEXT FIELD STYLE

struct BlueTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
    }
}

// MARK: - Data Models (Keep all existing models unchanged)
struct UserRankings {
    let globalDaily: Int?
    let globalWeekly: Int?
    let friendsDaily: Int?
    let friendsWeekly: Int?
    let todaySteps: Int
    let weeklySteps: Int
}

struct UserRankingResponse: Codable {
    let globalDailyRank: Int?
    let globalWeeklyRank: Int?
    let friendsDailyRank: Int?
    let friendsWeeklyRank: Int?
    let dailySteps: Int
    let weeklySteps: Int
    
    enum CodingKeys: String, CodingKey {
        case globalDailyRank = "global_daily_rank"
        case globalWeeklyRank = "global_weekly_rank"
        case friendsDailyRank = "friends_daily_rank"
        case friendsWeeklyRank = "friends_weekly_rank"
        case dailySteps = "daily_steps"
        case weeklySteps = "weekly_steps"
    }
}
