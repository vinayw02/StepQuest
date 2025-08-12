// AuthView.swift - REPLACE YOUR ENTIRE FILE WITH THIS:

import SwiftUI
import Supabase

struct AuthView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLogin: Bool = true
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    // Computed property for form validation
    private var isFormValid: Bool {
        let sanitizedUsername = username.sanitized
        return sanitizedUsername.isValidUsername &&
               password.isValidPassword &&
               !isLoading
    }
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            // Offline banner
            VStack {
                OfflineBanner(isOffline: !networkMonitor.isConnected)
                Spacer()
            }
            .zIndex(1)
            
            VStack(spacing: 32) {
                Spacer()
                
                // App Logo/Title
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("StepQuest")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Turn every step into progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Auth Form
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        ValidatedTextField(
                            title: "Username",
                            placeholder: "Enter username",
                            text: $username,
                            validation: { $0.sanitized.isValidUsername },
                            errorMessage: "Username must be 3-20 characters (letters, numbers, underscore only)",
                            maxLength: 20
                        )
                        
                        ValidatedSecureField(
                            title: "Password",
                            placeholder: "Enter password",
                            text: $password,
                            validation: { $0.isValidPassword },
                            errorMessage: "Password must be at least 8 characters with letters and numbers"
                        )
                    }
                    
                    LoadingButton(
                        title: isLogin ? "Sign In" : "Create Account",
                        isLoading: isLoading,
                        isDisabled: !isFormValid,
                        action: authenticate
                    )
                    
                    Button(action: { isLogin.toggle() }) {
                        Text(isLogin ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .alert("Authentication Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Authentication Method
    private func authenticate() {
        // Sanitize inputs
        let sanitizedUsername = username.sanitized
        let sanitizedPassword = password.sanitized
        
        // Additional validation
        guard sanitizedUsername.isValidUsername else {
            alertMessage = "Please enter a valid username"
            showAlert = true
            return
        }
        
        guard sanitizedPassword.isValidPassword else {
            alertMessage = "Please enter a valid password"
            showAlert = true
            return
        }
        
        // Check for inappropriate content
        guard !ProfanityFilter.shared.containsInappropriateContent(sanitizedUsername) else {
            alertMessage = "Username contains inappropriate content"
            showAlert = true
            return
        }
        
        // Rate limiting (prevent brute force)
        if AuthRateLimiter.shared.isBlocked(for: sanitizedUsername) {
            alertMessage = "Too many attempts. Please try again later."
            showAlert = true
            return
        }
        
        // Check network connection
        guard networkMonitor.isConnected else {
            alertMessage = "No internet connection. Please check your network and try again."
            showAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let email = "\(sanitizedUsername)@stepup.app" // Fake email format
                
                print("🔄 Attempting authentication with email: \(email)")
                
                if isLogin {
                    // Sign in existing user
                    let response = try await supabase.auth.signIn(
                        email: email,
                        password: sanitizedPassword
                    )
                    
                    print("✅ Sign in response: \(response)")
                    print("✅ User signed in successfully")
                    
                    // Clear rate limiting on successful login
                    AuthRateLimiter.shared.clearAttempts(for: sanitizedUsername)
                    
                } else {
                    // Sign up new user
                    print("🔄 Creating new user...")
                    let authResponse = try await supabase.auth.signUp(
                        email: email,
                        password: sanitizedPassword
                    )
                    
                    print("✅ Signup response: \(authResponse)")
                    
                    // Check if email confirmation is required
                    if authResponse.session == nil {
                        await MainActor.run {
                            isLoading = false
                            alertMessage = "Please check your email to confirm your account, then try signing in."
                            showAlert = true
                        }
                        return
                    }
                    
                    let userId = authResponse.user.id
                    print("✅ User created with ID: \(userId)")
                    
                    // Create user profile with sanitized data
                    let userProfile = UserProfileInsert(
                        id: userId,
                        username: sanitizedUsername,
                        displayName: sanitizedUsername
                    )
                    
                    print("🔄 Creating user profile...")
                    try await supabase
                        .from("user_profiles")
                        .insert(userProfile)
                        .execute()
                    
                    print("✅ User profile created")
                    
                    // Create initial user stats
                    let initialStats = UserStatsInsert(
                        userId: userId,
                        currentTierId: 1, // Start at Couch Potato
                        totalPoints: 0,
                        weeklyAverageSteps: 0,
                        lifetimeSteps: 0
                    )
                    
                    print("🔄 Creating user stats...")
                    try await supabase
                        .from("user_stats")
                        .insert(initialStats)
                        .execute()
                    
                    print("✅ User stats created")
                }
                
                await MainActor.run {
                    isLoading = false
                    NotificationCenter.default.post(name: .authStateChanged, object: nil)
                }
                
            } catch {
                // Record failed attempt for rate limiting
                AuthRateLimiter.shared.recordAttempt(for: sanitizedUsername)
                
                await MainActor.run {
                    isLoading = false
                    
                    // Provide user-friendly error messages
                    if error.localizedDescription.contains("Invalid login credentials") {
                        alertMessage = "Invalid username or password. Please try again."
                    } else if error.localizedDescription.contains("network") {
                        alertMessage = "Network error. Please check your connection and try again."
                    } else {
                        alertMessage = "Authentication failed. Please try again."
                    }
                    showAlert = true
                }
                print("❌ Auth error: \(error)")
            }
        }
    }
}

// MARK: - StepUpTextFieldStyle
struct StepUpTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
    }
}
