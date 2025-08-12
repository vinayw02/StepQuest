// AppStateManager.swift - CREATE THIS AS A NEW FILE

import Foundation
import SwiftUI
import Combine

// MARK: - App State
enum AppState: Equatable {
    case loading
    case unauthenticated
    case authenticated(UserProfile)
    case error(StepUpError)
    
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - App State Manager
@MainActor
class AppStateManager: ObservableObject {
    @Published var state: AppState = .loading
    @Published var isShowingRecap = false
    
    private let dependencies: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // Use cases
    private lazy var authenticateUseCase = AuthenticateUserUseCase(
        userRepository: dependencies.userRepository,
        analytics: dependencies.analytics,
        logger: dependencies.logger
    )
    
    private lazy var syncStepsUseCase = SyncStepsUseCase(
        healthManager: dependencies.healthManager,
        stepsRepository: dependencies.stepsRepository,
        analytics: dependencies.analytics,
        logger: dependencies.logger
    )
    
    init(dependencies: DependencyContainer) {
        self.dependencies = dependencies
        setupStateObservation()
        checkInitialAuthState()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    private func setupStateObservation() {
        // Monitor authentication changes
        NotificationCenter.default
            .publisher(for: .authStateChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAuthenticationState()
                }
            }
            .store(in: &cancellables)
        
        // Monitor network state - using concrete type
        if let appContainer = dependencies as? ConcreteDependencyContainer {
            appContainer.concreteNetworkMonitor.$isConnected
                .sink { [weak self] isConnected in
                    self?.dependencies.logger.info("Network state changed: \(isConnected ? "connected" : "disconnected")", file: #file, function: #function, line: #line)
                }
                .store(in: &cancellables)
        }
    }
    
    private func checkInitialAuthState() {
        Task {
            await checkAuthenticationState()
        }
    }
    
    func checkAuthenticationState() async {
        dependencies.logger.info("Checking authentication state", file: #file, function: #function, line: #line)
        
        do {
            if let user = try await dependencies.userRepository.getCurrentUser() {
                dependencies.logger.info("User authenticated: \(user.username)", file: #file, function: #function, line: #line)
                dependencies.analytics.setUserProperty(user.username, forName: "username")
                
                // Start health tracking for authenticated users
                dependencies.healthManager.startTrackingForAuthenticatedUser()
                
                state = .authenticated(user)
            } else {
                dependencies.logger.info("No authenticated user found", file: #file, function: #function, line: #line)
                dependencies.healthManager.stopTracking()
                state = .unauthenticated
            }
        } catch {
            dependencies.logger.error("Authentication check failed", error: error, file: #file, function: #function, line: #line)
            dependencies.analytics.logError(error, additionalInfo: ["context": "auth_check"])
            
            if error.localizedDescription.contains("network") {
                state = .error(.networkUnavailable)
            } else {
                state = .error(.supabaseAuthError(error.localizedDescription))
            }
        }
    }
    
    func signIn(username: String, password: String) async {
        dependencies.logger.info("Attempting sign in for: \(username)", file: #file, function: #function, line: #line)
        state = .loading
        
        do {
            let user = try await authenticateUseCase.execute(
                username: username,
                password: password,
                isSignUp: false
            )
            
            dependencies.analytics.track(event: "user_signin_success", parameters: [
                "username": user.username
            ])
            
            state = .authenticated(user)
            
        } catch {
            dependencies.logger.error("Sign in failed", error: error, file: #file, function: #function, line: #line)
            dependencies.analytics.track(event: "user_signin_failed", parameters: [
                "username": username,
                "error": error.localizedDescription
            ])
            
            if let stepUpError = error as? StepUpError {
                state = .error(stepUpError)
            } else {
                state = .error(.supabaseAuthError(error.localizedDescription))
            }
        }
    }
    
    func signUp(username: String, password: String) async {
        dependencies.logger.info("Attempting sign up for: \(username)", file: #file, function: #function, line: #line)
        state = .loading
        
        do {
            let user = try await authenticateUseCase.execute(
                username: username,
                password: password,
                isSignUp: true
            )
            
            dependencies.analytics.track(event: "user_signup_success", parameters: [
                "username": user.username
            ])
            
            state = .authenticated(user)
            
        } catch {
            dependencies.logger.error("Sign up failed", error: error, file: #file, function: #function, line: #line)
            dependencies.analytics.track(event: "user_signup_failed", parameters: [
                "username": username,
                "error": error.localizedDescription
            ])
            
            if let stepUpError = error as? StepUpError {
                state = .error(stepUpError)
            } else {
                state = .error(.supabaseAuthError(error.localizedDescription))
            }
        }
    }
    
    func signOut() async {
        dependencies.logger.info("Signing out user", file: #file, function: #function, line: #line)
        
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            dependencies.healthManager.stopTracking()
            dependencies.analytics.track(event: "user_signout", parameters: nil)
            
            state = .unauthenticated
            
        } catch {
            dependencies.logger.error("Sign out failed", error: error, file: #file, function: #function, line: #line)
            dependencies.analytics.logError(error, additionalInfo: ["context": "signout"])
            
            // Even if sign out fails, treat as unauthenticated locally
            state = .unauthenticated
        }
    }
    
    func syncSteps() async {
        guard case .authenticated(let user) = state else {
            dependencies.logger.warning("Attempted to sync steps while not authenticated", file: #file, function: #function, line: #line)
            return
        }
        
        do {
            try await syncStepsUseCase.execute(for: user.id)
            dependencies.logger.info("Steps sync completed successfully", file: #file, function: #function, line: #line)
        } catch {
            dependencies.logger.error("Steps sync failed", error: error, file: #file, function: #function, line: #line)
            dependencies.analytics.logError(error, additionalInfo: [
                "user_id": user.id.uuidString,
                "context": "manual_sync"
            ])
        }
    }
    
    func retryLastOperation() async {
        dependencies.logger.info("Retrying last operation", file: #file, function: #function, line: #line)
        
        switch state {
        case .error(.networkUnavailable), .error(.backgroundSyncFailed):
            await checkAuthenticationState()
        case .error(.supabaseAuthError):
            state = .unauthenticated
        default:
            dependencies.logger.warning("No retryable operation available", file: #file, function: #function, line: #line)
        }
    }
    
    func clearError() {
        if case .error = state {
            state = .unauthenticated
        }
    }
}

// MARK: - App State Extensions
extension AppState {
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    var currentUser: UserProfile? {
        if case .authenticated(let user) = self {
            return user
        }
        return nil
    }
    
    var currentError: StepUpError? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}
