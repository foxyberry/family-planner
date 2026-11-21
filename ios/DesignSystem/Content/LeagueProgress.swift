import CrayonKit
import KitArt
import SwiftUI

/// Progress to the next bus league. The bar only grows, never shrinks.
public struct LeagueProgress: View {
    private let level: KitSlot
    private let levelName: String
    private let done: Int
    private let goal: Int
    private let remaining: String
    @Environment(\.sizing) private var sizing

    /// `remaining`: the words under the bar (`LeagueText.remaining` in Domain).
    public init(level: KitSlot, levelName: String, done: Int, goal: Int, remaining: String) {
        self.level = level
        self.levelName = levelName
        self.done = done
        self.goal = goal
        self.remaining = remaining
    }

    /// Share of the goal reached, capped at 1.
    nonisolated public static func fraction(done: Int, goal: Int) -> Double {
        guard goal > 0 else { return 1 }
        return min(Double(max(done, 0)) / Double(goal), 1)
    }

    public var body: some View {
        HStack(spacing: sizing(Spacing.m)) {
            KitIcon(level, size: sizing(88))
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                Text(levelName).crayonType(.head)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        CrayonSurface(.capsule, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.league)
                        CrayonSurface(.capsule, fill: CrayonStyle.yellowSlider, seed: CrayonStyle.Seed.league + 1)
                            .frame(width: max(geometry.size.width * Self.fraction(done: done, goal: goal), sizing(40)))
                    }
                }
                .frame(height: sizing(40))
                Text(remaining)
                    .crayonType(.caption)
                    .foregroundStyle(CrayonColor.softText)
            }
        }
        .foregroundStyle(CrayonColor.ink)
    }
}
