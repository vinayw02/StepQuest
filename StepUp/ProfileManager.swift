import SwiftUI
import PhotosUI
import Supabase
import Combine

@MainActor
class ProfileManager: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var userStats: UserStats?
    @Published var currentTier: Tier?
    @Published var profileImage: UIImage?
    @Published var todaySteps: Int = 0
    @Published var weeklyAverage: Int = 0
    @Published var selectedPhoto: PhotosPickerItem? {
        didSet {
            if let selectedPhoto = selectedPhoto {
                loadSelectedPhoto(selectedPhoto)
            }
        }
    }
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var userTimezone: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let supabase = SupabaseManager.shared.client
    private let healthManager = HealthManager.shared
    
    init() {
        loadUserProfile()
        // Subscribe to HealthManager updates
        setupHealthManagerObservation()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private func setupHealthManagerObservation() {
        // Replace NotificationCenter with Combine for better memory management
        healthManager.$todaySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] steps in
                self?.todaySteps = steps
            }
            .store(in: &cancellables)
        
        healthManager.$weeklyAverage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] average in
                self?.weeklyAverage = average
            }
            .store(in: &cancellables)
    }
    
    private func fetchStepsFromHealthManager() async {
        // Get the same data that HealthManager calculates
        await healthManager.fetchTodaySteps()
        await healthManager.fetchWeeklySteps()
        
        await MainActor.run {
            self.todaySteps = healthManager.todaySteps
            self.weeklyAverage = healthManager.weeklyAverage
            print("📊 ProfileManager synced with HealthManager:")
            print("   Today's steps: \(self.todaySteps)")
            print("   Weekly average: \(self.weeklyAverage)")
        }
    }
    
    func loadUserProfile() {
        Task {
            isLoading = true
            
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                print("🔄 Loading profile for user: \(userId)")
                
                // Fetch user profile
                let profileResponse: [UserProfile] = try await supabase
                    .from("user_profiles")
                    .select("id, username, display_name, avatar_url, timezone, created_at, updated_at")
                    .eq("id", value: userId)
                    .execute()
                    .value
                
                print("✅ Profile response: \(profileResponse)")
                
                // Fetch user stats
                let statsResponse: [UserStats] = try await supabase
                    .from("user_stats")
                    .select("id, user_id, current_tier_id, total_points, weekly_average_steps, lifetime_steps, current_streak_days, longest_streak_days, last_calculated_at")
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                
                print("✅ Stats response: \(statsResponse)")
                
                // Get steps data from HealthManager for consistency
                await fetchStepsFromHealthManager()
                
                await MainActor.run {
                    self.userProfile = profileResponse.first
                    self.userTimezone = profileResponse.first?.timezone
                    self.userStats = statsResponse.first
                    
                    // Set current tier
                    if let stats = self.userStats,
                       let tierId = stats.currentTierId {
                        self.currentTier = globalTierList.first { $0.id == tierId }
                    }
                    
                    self.isLoading = false
                    
                    // Debug prints
                    print("📊 Final profile data:")
                    print("   Username: \(self.userProfile?.username ?? "nil")")
                    print("   Display name: \(self.userProfile?.displayName ?? "nil")")
                    print("   Today steps: \(self.todaySteps)")
                    print("   Weekly average: \(self.weeklyAverage)")
                    print("   Current tier: \(self.currentTier?.name ?? "nil")")
                }
                
                // Load profile image if URL exists
                if let avatarUrl = profileResponse.first?.avatarUrl,
                   !avatarUrl.isEmpty {
                    await loadProfileImage(from: avatarUrl)
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Failed to load profile: \(error.localizedDescription)"
                }
                print("❌ Error loading profile: \(error)")
                
                // More detailed error logging
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("❌ Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("❌ Key not found: \(key) in \(context)")
                    case .typeMismatch(let type, let context):
                        print("❌ Type mismatch: \(type) in \(context)")
                    case .valueNotFound(let type, let context):
                        print("❌ Value not found: \(type) in \(context)")
                    @unknown default:
                        print("❌ Unknown decoding error: \(decodingError)")
                    }
                }
            }
        }
    }
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run {
                        self.alertMessage = "Failed to load selected image"
                    }
                    return
                }
                
                await MainActor.run {
                    self.profileImage = image
                }
                
                // Upload the image
                await uploadProfileImage(image: image, imageData: data)
                
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to process image: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func uploadProfileImage(image: UIImage, imageData: Data) async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔄 Starting image upload for user: \(userId)")
            
            // Create unique filename
            let fileName = "\(userId)_\(Date().timeIntervalSince1970).jpg"
            let filePath = "avatars/\(fileName)"
            
            print("🔄 Uploading to path: \(filePath)")
            
            // Upload to Supabase Storage - using Data directly
            try await supabase.storage
                .from("profile-images")
                .upload(path: filePath, file: imageData, options: FileOptions(upsert: true))
            
            print("✅ Image uploaded successfully")
            
            // Get public URL
            let publicURL = try supabase.storage
                .from("profile-images")
                .getPublicURL(path: filePath)
            
            print("✅ Got public URL: \(publicURL)")
            
            print("🔄 Updating user profile with avatar URL...")
            
            // Update user profile with new avatar URL
            try await supabase
                .from("user_profiles")
                .update(["avatar_url": publicURL.absoluteString])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Profile updated successfully")
            
            // Update local profile by creating new instance
            await MainActor.run {
                if let currentProfile = self.userProfile {
                    self.userProfile = currentProfile.updated(avatarUrl: publicURL.absoluteString)
                }
                self.alertMessage = "Profile picture updated successfully!"
            }
            
        } catch {
            await MainActor.run {
                self.alertMessage = "Failed to upload image: \(error.localizedDescription)"
            }
            print("❌ Error uploading profile image: \(error)")
            print("❌ Error details: \(error)")
        }
    }
    
    private func loadProfileImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            
            await MainActor.run {
                self.profileImage = image
            }
        } catch {
            print("Error loading profile image: \(error)")
        }
    }
    
    func updateUsername(_ newUsername: String) async {
        guard !newUsername.isEmpty else {
            alertMessage = "Username cannot be empty"
            return
        }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Check if username is already taken
            let existingUsers: [UserProfile] = try await supabase
                .from("user_profiles")
                .select("id")
                .eq("username", value: newUsername)
                .neq("id", value: userId)
                .execute()
                .value
            
            if !existingUsers.isEmpty {
                await MainActor.run {
                    self.alertMessage = "Username is already taken"
                }
                return
            }
            
            // Update username
            try await supabase
                .from("user_profiles")
                .update([
                    "username": newUsername,
                    "display_name": newUsername,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                if let currentProfile = self.userProfile {
                    self.userProfile = currentProfile.updated(username: newUsername, displayName: newUsername)
                }
                self.alertMessage = "Username updated successfully!"
            }
            
        } catch {
            await MainActor.run {
                self.alertMessage = "Failed to update username: \(error.localizedDescription)"
            }
            print("Error updating username: \(error)")
        }
    }
    
    func updateTimezone(_ timezone: String) async {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            try await supabase.rpc("set_user_timezone", params: [
                "user_id_param": userId.uuidString,
                "tz": timezone
            ]).execute()
            
            await MainActor.run {
                self.userTimezone = timezone
                self.alertMessage = "Timezone updated successfully!"
            }
            
        } catch {
            await MainActor.run {
                self.alertMessage = "Failed to update timezone: \(error.localizedDescription)"
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                await MainActor.run {
                    NotificationCenter.default.post(name: .authStateChanged, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Failed to sign out: \(error.localizedDescription)"
                }
            }
        }
    }
}
