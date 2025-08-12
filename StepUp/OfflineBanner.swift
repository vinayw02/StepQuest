// OfflineBanner.swift - CORRECTED VERSION

import SwiftUI

struct OfflineBanner: View {
    let isOffline: Bool
    
    var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Offline mode - data will sync when connected")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct RetryView: View {
    let error: StepUpError
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if error.isRetryable {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(PrimaryButtonStyle()) // This will use the existing one from HomeView.swift
            }
        }
        .padding()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// NOTE: PrimaryButtonStyle is already defined in HomeView.swift, so we don't need to redefine it here
