// CreateGroupView.swift - CREATE THIS AS A NEW FILE

import SwiftUI

struct CreateGroupView: View {
    @ObservedObject var groupsManager: GroupsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedResetPeriod: LeaderboardResetPeriod = .weekly
    @State private var isCreating = false
    
    private var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        groupName.count >= 3 &&
        groupName.count <= 50
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
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Text("Create Group")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Start competing with friends")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 24) {
                            // Group Name
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Group Name")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                TextField("Enter group name", text: $groupName)
                                    .textFieldStyle(BlueTextFieldStyle())
                                    .autocapitalization(.words)
                                
                                Text("\(groupName.count)/50")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            
                            // Group Description (Optional)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Description (Optional)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                TextField("What's this group about?", text: $groupDescription, axis: .vertical)
                                    .textFieldStyle(BlueTextFieldStyle())
                                    .lineLimit(3...6)
                                
                                Text("\(groupDescription.count)/200")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            
                            // Reset Period Selection
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Leaderboard Reset")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Choose how often the group leaderboard resets")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 12) {
                                    ForEach(LeaderboardResetPeriod.allCases, id: \.self) { period in
                                        ResetPeriodOption(
                                            period: period,
                                            isSelected: selectedResetPeriod == period,
                                            onTap: {
                                                selectedResetPeriod = period
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Create Button
                        VStack(spacing: 16) {
                            Button(action: createGroup) {
                                HStack(spacing: 12) {
                                    if isCreating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20, weight: .medium))
                                    }
                                    
                                    Text("Create Group")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: isFormValid ?
                                            [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)] :
                                            [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: isFormValid ? Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3) : Color.clear, radius: 12, x: 0, y: 6)
                            }
                            .disabled(!isFormValid || isCreating)
                            
                            if !isFormValid && !groupName.isEmpty {
                                Text("Group name must be between 3-50 characters")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                        .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                },
                alignment: .topLeading
            )
        }
        .onChange(of: groupName) { newValue in
            if newValue.count > 50 {
                groupName = String(newValue.prefix(50))
            }
        }
        .onChange(of: groupDescription) { newValue in
            if newValue.count > 200 {
                groupDescription = String(newValue.prefix(200))
            }
        }
    }
    
    private func createGroup() {
        guard isFormValid else { return }
        
        isCreating = true
        
        Task {
            let success = await groupsManager.createGroup(
                name: groupName,
                description: groupDescription.isEmpty ? nil : groupDescription,
                resetPeriod: selectedResetPeriod
            )
            
            await MainActor.run {
                isCreating = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Reset Period Option

struct ResetPeriodOption: View {
    let period: LeaderboardResetPeriod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                                Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.2) :
                                Color.gray.opacity(0.1)
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: period.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(
                            isSelected ?
                                Color(red: 0.2, green: 0.7, blue: 0.9) :
                                .secondary
                        )
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(period.shortDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(period.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ?
                                Color(red: 0.2, green: 0.7, blue: 0.9) :
                                Color.gray.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.9))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ?
                                    Color(red: 0.2, green: 0.7, blue: 0.9).opacity(0.3) :
                                    Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Join Group View

struct JoinGroupView: View {
    @ObservedObject var groupsManager: GroupsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var isJoining = false
    
    private var isFormValid: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        inviteCode.count >= 6
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
                
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Join Group")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Enter the invite code to join a group")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Invite code input
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Invite Code")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            TextField("Enter invite code", text: $inviteCode)
                                .textFieldStyle(BlueTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                            
                            Text("Ask your friend for their group's invite code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Join Button
                        Button(action: joinGroup) {
                            HStack(spacing: 12) {
                                if isJoining {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 20, weight: .medium))
                                }
                                
                                Text("Join Group")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: isFormValid ?
                                        [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.6, blue: 0.8)] :
                                        [Color.gray.opacity(0.6), Color.gray.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: isFormValid ? Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.3) : Color.clear, radius: 12, x: 0, y: 6)
                        }
                        .disabled(!isFormValid || isJoining)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.9))
                        .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                },
                alignment: .topLeading
            )
        }
        .onChange(of: inviteCode) { newValue in
            inviteCode = newValue.uppercased()
        }
    }
    
    private func joinGroup() {
        guard isFormValid else { return }
        
        isJoining = true
        
        Task {
            let success = await groupsManager.joinGroupByInviteCode(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isJoining = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
