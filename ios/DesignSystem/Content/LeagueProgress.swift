import CrayonKit
import KitArt
import Strings
import SwiftUI

/// Progress to the next bus league. The bar only grows, never shrinks.
public struct LeagueProgress: View {
    private let level: KitSlot
    private let levelName: String
    private let done: Int
    private let goal: Int
    private let nextName: String

    public init(level: KitSlot, levelName: String, done: Int, goal: Int, nextName: String) {
        self.level = level
        self.levelName = levelName
        self.done = done
        self.goal = goal
        self.nextName = nextName
    }

    /// Share of the goal reached, capped at 1.
    nonisolated public static func fraction(done: Int, goal: Int) -> Double {
        guard goal > 0 else { return 1 }
        return min(Double(max(done, 0)) / Double(goal), 1)
    }

    /// "12 more Go! days to the Double-Decker".
    nonisolated public static func remainingText(done: Int, goal: Int, nextName: String) -> String {
        let left = max(goal - done, 0)
        guard left > 0 else { return L10n.tr("league.next_stop", nextName) }
        return left == 1 ? L10n.tr("league.left.one", left, nextName) : L10n.tr("league.left.other", left, nextName)
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            KitIcon(level, size: 88)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(levelName).crayonType(.head)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        CrayonSurface(.capsule, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.league)
                        CrayonSurface(.capsule, fill: CrayonStyle.yellowSlider, seed: CrayonStyle.Seed.league + 1)
                            .frame(width: max(geometry.size.width * Self.fraction(done: done, goal: goal), 40))
                    }
                }
                .frame(height: 40)
                Text(Self.remainingText(done: done, goal: goal, nextName: nextName))
                    .crayonType(.caption)
                    .foregroundStyle(CrayonColor.softText)
            }
        }
        .foregroundStyle(CrayonColor.ink)
        .accessibilityElement(children: .combine)
    }
}
