// ContentView.swift - UPDATED WITH BLUE THEME

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @StateObject private var recapManager = RecapManager()
    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    var body: some View {
        ZStack {
            // FIXED: Removed Group wrapper that was causing the decoder error
            if isLoading {
                SplashScreen()
            } else if isAuthenticated {
                MainTabView()
                    .onAppear {
                        // Start tracking and check for recaps when authenticated
                        HealthManager.shared.startTrackingForAuthenticatedUser()
                        
                        // NEW: Run 7-day catch-up sync when app opens
                        Task {
                            await HealthManager.shared.syncLast7Days()
                        }
                        
                        // Check for recap after a short delay to ensure data is loaded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            recapManager.checkForRecapOnAppOpen()
                        }
                    }
            } else {
                AuthView()
            }
            
            // Recap Overlay - Shows on top of everything when needed
            if recapManager.shouldShowRecap {
                RecapOverlayView(recapManager: recapManager)
                    .zIndex(1000) // Ensure it appears on top
            }
        }
        .onAppear {
            checkAuthStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateChanged)) { _ in
            checkAuthStatus()
        }
    }
    
    private func checkAuthStatus() {
        Task {
            do {
                let session = try await supabase.auth.session
                await MainActor.run {
                    isAuthenticated = session.accessToken != nil
                    isLoading = false
                    
                    if !isAuthenticated {
                        HealthManager.shared.stopTracking()
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticated = false
                    isLoading = false
                    HealthManager.shared.stopTracking()
                }
            }
        }
    }
}

// MARK: - Splash Screen
// Updated SplashScreen for ContentView.swift
// Replace the existing SplashScreen struct with this updated version

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // StepQuest Logo - Using your new SQ logo
                ZStack {
                    // Animated background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.1),
                                    Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                    
                    // Main logo container
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            // SQ text logo
                            HStack(spacing: 2) {
                                Text("S")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Q")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .overlay(
                                // Small walking figure in the S
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .offset(x: -18, y: 5)
                            )
                        )
                        .shadow(
                            color: Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.4),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }
                
                // App name and tagline
                VStack(spacing: 8) {
                    Text("StepQuest")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.7, blue: 0.9),
                                    Color(red: 0.1, green: 0.6, blue: 0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                    
                    Text("Your Step Adventure Begins")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(textOpacity)
                }
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Color(red: 0.2, green: 0.7, blue: 0.9))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Main Tab View - UPDATED WITH GROUPS TAB
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            LeaderboardView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }
                .tag(1)
            
            GroupsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Groups")
                }
                .tag(2)
            
            FriendsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.2, green: 0.7, blue: 0.9)) // CHANGED FROM GREEN TO BLUE
        .onAppear {
            // Customize tab bar appearance for blue theme
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // Selected item color (blue)
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color(red: 0.2, green: 0.7, blue: 0.9))
            ]
            
            // Unselected item color
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.systemGray
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Extensions
extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
}
