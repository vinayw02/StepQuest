import UIKit
import BackgroundTasks
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // FIXED: Register background tasks IMMEDIATELY on app launch
        registerBackgroundTasks()
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("Notification permission granted: \(granted)")
        }
        
        // Request background app refresh permission
        requestBackgroundAppRefresh()
        
        // Initialize background health manager
        _ = BackgroundHealthManager.shared
        
        return true
    }
    
    // NEW: Register background tasks immediately
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.stepquest.background-health-sync",
            using: nil
        ) { task in
            print("🔄 Background task started: \(task.identifier)")
            self.handleBackgroundHealthSync(task: task as! BGAppRefreshTask)
        }
        print("✅ Background task registered: com.stepquest.background-health-sync")
    }
    
    // NEW: Handle background sync
    private func handleBackgroundHealthSync(task: BGAppRefreshTask) {
        // Schedule next task immediately
        scheduleBackgroundSync()
        
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        Task {
            print("🔄 Starting background health sync...")
            await BackgroundHealthManager.shared.performBackgroundDataSync()
            print("✅ Background health sync completed")
            task.setTaskCompleted(success: true)
        }
    }
    
    // NEW: Schedule background sync
    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.stepquest.background-health-sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Next background sync scheduled for 1 hour from now")
        } catch {
            print("❌ Failed to schedule background sync: \(error)")
        }
    }
    
    private func requestBackgroundAppRefresh() {
        // This will prompt user to enable background app refresh for this app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if UIApplication.shared.backgroundRefreshStatus != .available {
                print("⚠️ Background App Refresh is not available. Please enable it in Settings.")
                self.showBackgroundRefreshAlert()
            } else {
                print("✅ Background App Refresh is available")
                // Schedule first background sync
                self.scheduleBackgroundSync()
            }
        }
    }
    
    private func showBackgroundRefreshAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "Background Refresh Required",
            message: "To earn points automatically as you walk, please enable Background App Refresh for StepQuest in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(tokenString)")
    }
}
