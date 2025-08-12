import SwiftUI

// MARK: - Tier Data Structure
struct Tier: Codable, Identifiable {
    let id: Int
    let name: String
    let pointsRequired: Int
    let icon: String?
    let colorPrimary: String?
    let colorSecondary: String?
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pointsRequired = "points_required"
        case icon
        case colorPrimary = "color_primary"
        case colorSecondary = "color_secondary"
        case sortOrder = "sort_order"
    }
}

// MARK: - Global Tier List
let globalTierList: [Tier] = [
    Tier(
        id: 1,
        name: "Couch Potato",
        pointsRequired: 0,
        icon: "figure.seated.side",
        colorPrimary: "#8E8E93",
        colorSecondary: "#636366",
        sortOrder: 1
    ),
    Tier(
        id: 2,
        name: "Weekend Walker",
        pointsRequired: 500,
        icon: "figure.walk",
        colorPrimary: "#34C759",
        colorSecondary: "#30D158",
        sortOrder: 2
    ),
    Tier(
        id: 3,
        name: "Daily Stepper",
        pointsRequired: 1500,
        icon: "figure.walk.motion",
        colorPrimary: "#007AFF",
        colorSecondary: "#0A84FF",
        sortOrder: 3
    ),
    Tier(
        id: 4,
        name: "Stride Master",
        pointsRequired: 3000,
        icon: "figure.run",
        colorPrimary: "#FF9500",
        colorSecondary: "#FF9F0A",
        sortOrder: 4
    ),
    Tier(
        id: 5,
        name: "Step Legend",
        pointsRequired: 5000,
        icon: "flame.fill",
        colorPrimary: "#FF3B30",
        colorSecondary: "#FF453A",
        sortOrder: 5
    ),
    Tier(
        id: 6,
        name: "Walking Titan",
        pointsRequired: 8000,
        icon: "crown.fill",
        colorPrimary: "#AF52DE",
        colorSecondary: "#BF5AF2",
        sortOrder: 6
    ),
    Tier(
        id: 7,
        name: "Step God",
        pointsRequired: 12000,
        icon: "infinity",
        colorPrimary: "#FFD60A",
        colorSecondary: "#FFCC02",
        sortOrder: 7
    )
]

// MARK: - Tier Helper Functions
extension Array where Element == Tier {
    func getTier(for points: Int) -> Tier {
        return self.last { $0.pointsRequired <= points } ?? self.first!
    }
    
    func getNextTier(for currentTier: Tier) -> Tier? {
        guard let currentIndex = self.firstIndex(where: { $0.id == currentTier.id }),
              currentIndex < self.count - 1 else { return nil }
        return self[currentIndex + 1]
    }
}
