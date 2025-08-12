// StepUpApp.swift - REPLACE YOUR ENTIRE FILE WITH THIS:

import SwiftUI
import UserNotifications

@main
struct StepUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appStateManager: AppStateManager
    
    // Global logger instance
    private let logger: LoggerProtocol = ConsoleLogger()
    
    init() {
        // Set up dependency injection
        let dependencies = AppDependencyContainer()
        _appStateManager = StateObject(wrappedValue: AppStateManager(dependencies: dependencies))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateManager)
                .preferredColorScheme(.light)
                .onAppear {
                    logger.info("StepUp app launched", file: #file, function: #function, line: #line)
                    setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    logger.info("App became active", file: #file, function: #function, line: #line)
                    Task {
                        await appStateManager.checkAuthenticationState()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    logger.info("App will resign active", file: #file, function: #function, line: #line)
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func setupApp() {
        // Configure global settings
        configureAppearance()
        
        // Schedule background tasks when app appears
        BackgroundHealthManager.shared.scheduleNextBackgroundSync()
        
        // Log app startup analytics
        let dependencies = AppDependencyContainer()
        dependencies.analytics.track(event: "app_launched", parameters: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.systemBackground
        navBarAppearance.shadowColor = UIColor.clear
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    // MARK: - URL Handling for Group Invites
    
    private func handleIncomingURL(_ url: URL) {
        logger.info("📱 Received URL: \(url)", file: #file, function: #function, line: #line)
        
        // Check if it's a group invite link: stepup://join?code=ABC123
        if url.scheme == "stepup" && url.host == "join" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let inviteCode = queryItems.first(where: { $0.name == "code" })?.value {
                
                logger.info("🔗 Invite code from URL: \(inviteCode)", file: #file, function: #function, line: #line)
                
                // Handle the invite code
                handleGroupInvite(inviteCode: inviteCode)
            }
        }
    }
    
    private func handleGroupInvite(inviteCode: String) {
        // Wait a moment for the app to fully load, then show the invite dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            
            // Only show invite dialog if user is authenticated
            guard case .authenticated = appStateManager.state else {
                logger.warning("Received group invite but user not authenticated", file: #file, function: #function, line: #line)
                // Could store the invite code to handle after login
                UserDefaults.standard.set(inviteCode, forKey: "pendingGroupInvite")
                return
            }
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                let alert = UIAlertController(
                    title: "Join Group",
                    message: "You've been invited to join a StepUp group!\n\nInvite Code: \(inviteCode)",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Join Now", style: .default) { _ in
                    // Trigger the join group flow
                    self.joinGroupWithCode(inviteCode)
                })
                
                alert.addAction(UIAlertAction(title: "Later", style: .cancel) { _ in
                    // Store the invite code for later
                    UserDefaults.standard.set(inviteCode, forKey: "pendingGroupInvite")
                })
                
                // Find the topmost view controller to present the alert
                var topController = rootViewController
                while let presentedVC = topController.presentedViewController {
                    topController = presentedVC
                }
                
                topController.present(alert, animated: true)
            }
        }
    }
    
    private func joinGroupWithCode(_ inviteCode: String) {
        Task {
            // Create a temporary GroupsManager to handle the join
            let groupsManager = GroupsManager()
            let success = await groupsManager.joinGroupByInviteCode(inviteCode)
            
            await MainActor.run {
                // Show success/failure feedback
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    let message = success ? "Successfully joined the group!" : "Failed to join group. Please try again."
                    let alert = UIAlertController(title: "Group Invite", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    var topController = rootViewController
                    while let presentedVC = topController.presentedViewController {
                        topController = presentedVC
                    }
                    
                    topController.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Check for Pending Invites
    
    func checkForPendingGroupInvites() {
        // Call this when user successfully authenticates
        if let pendingInvite = UserDefaults.standard.string(forKey: "pendingGroupInvite") {
            UserDefaults.standard.removeObject(forKey: "pendingGroupInvite")
            handleGroupInvite(inviteCode: pendingInvite)
        }
    }
}
