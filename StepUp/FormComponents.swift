// FormComponents.swift - CREATE THIS AS A NEW FILE

import SwiftUI

// MARK: - Validated Text Field
struct ValidatedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let validation: (String) -> Bool
    let errorMessage: String
    var maxLength: Int = 50
    
    @State private var showError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(StepUpTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: text) { newValue in
                        // Limit input length
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                        
                        // Show/hide error based on validation
                        showError = !newValue.isEmpty && !validation(newValue)
                    }
                
                // Validation indicator
                if !text.isEmpty {
                    Image(systemName: validation(text) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(validation(text) ? .green : .red)
                        .font(.title3)
                }
            }
            
            // Error message
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showError)
    }
}

// MARK: - Validated Secure Field
// MARK: - Validated Secure Field
struct ValidatedSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let validation: (String) -> Bool
    let errorMessage: String
    
    @State private var showError = false
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                // FIXED: Removed Group and applied textFieldStyle directly to each field
                if showPassword {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(StepUpTextFieldStyle())
                        .onChange(of: text) { newValue in
                            showError = !newValue.isEmpty && !validation(newValue)
                        }
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(StepUpTextFieldStyle())
                        .onChange(of: text) { newValue in
                            showError = !newValue.isEmpty && !validation(newValue)
                        }
                }
                
                // Toggle password visibility
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                
                // Validation indicator
                if !text.isEmpty {
                    Image(systemName: validation(text) ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(validation(text) ? .green : .red)
                        .font(.title3)
                }
            }
            
            // Error message
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showError)
    }
}

// MARK: - Loading Button
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? Color.gray : Color.green)
            )
        }
        .disabled(isLoading || isDisabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}
