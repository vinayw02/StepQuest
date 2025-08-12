import SwiftUI

struct OnTrackView: View {
    let todaySteps: Int
    let weeklyAverage: Int  // This should now come from database
    
    private var projectedPointsChange: Int {
        let difference = todaySteps - weeklyAverage
        
        if difference >= 0 {
            // Earning points: +100 for every 500 steps above average
            let bonusSteps = difference
            let pointsEarned = (bonusSteps / 500) * 100
            return pointsEarned
        } else {
            // Losing points: -50 for every 500 steps below average
            let missedSteps = abs(difference)
            let pointsLost = (missedSteps / 500) * 50
            return -pointsLost
        }
    }
    
    private var trackingMessage: String {
        let difference = todaySteps - weeklyAverage
        
        if difference >= 0 {
            if projectedPointsChange == 0 {
                return "You're on track to maintain your points today"
            } else {
                return "You're on track to earn \(projectedPointsChange) points today"
            }
        } else {
            if projectedPointsChange == 0 {
                return "You're on track to maintain your points today"
            } else {
                return "You're on track to lose \(abs(projectedPointsChange)) points today"
            }
        }
    }
    
    private var trackingColor: Color {
        if projectedPointsChange > 0 {
            return .green
        } else if projectedPointsChange < 0 {
            return .red
        } else {
            return .blue
        }
    }
    
    private var trackingIcon: String {
        if projectedPointsChange > 0 {
            return "arrow.up.circle.fill"
        } else if projectedPointsChange < 0 {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle.fill"
        }
    }
    
    private var progressDetails: String {
        let difference = todaySteps - weeklyAverage
        
        if difference >= 0 {
            // Steps above average - calculate steps to next 500 milestone
            let currentBonus = difference
            let stepsToNext = 500 - (currentBonus % 500)
            
            if currentBonus == 0 {
                return "Walk \(stepsToNext) more steps to earn your first 100 points"
            } else if stepsToNext == 500 {
                return "Walk 500 more steps to earn another 100 points"
            } else {
                return "Walk \(stepsToNext) more steps to earn another 100 points"
            }
        } else {
            // Steps below average - calculate steps needed to avoid losing points
            let deficit = abs(difference)
            
            if deficit < 500 {
                return "Walk \(500 - deficit) more steps to avoid losing points"
            } else {
                let stepsToReduceLoss = 500 - (deficit % 500)
                if stepsToReduceLoss == 500 {
                    return "Walk 500 more steps to reduce your point loss"
                } else {
                    return "Walk \(stepsToReduceLoss) more steps to reduce your point loss"
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: trackingIcon)
                    .font(.title2)
                    .foregroundColor(trackingColor)
                
                Text("On Track")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Main tracking message
                Text(trackingMessage)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(trackingColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress details
                Text(progressDetails)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress bar showing steps vs average
                ProgressTrackingBar(
                    currentSteps: todaySteps,
                    averageSteps: weeklyAverage
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(trackingColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(trackingColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct ProgressTrackingBar: View {
    let currentSteps: Int
    let averageSteps: Int
    
    private var progressPercentage: Double {
        guard averageSteps > 0 else { return 0 }
        return min(Double(currentSteps) / Double(averageSteps), 2.0) // Cap at 200%
    }
    
    private var barColor: Color {
        if currentSteps >= averageSteps {
            return .green
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress vs Average")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(currentSteps) / \(averageSteps)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(
                            width: geometry.size.width * progressPercentage,
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.5), value: progressPercentage)
                    
                    // Average line marker
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary)
                        .frame(width: 2, height: 12)
                        .offset(x: geometry.size.width * 0.5 - 1)
                }
            }
            .frame(height: 12)
        }
    }
}
