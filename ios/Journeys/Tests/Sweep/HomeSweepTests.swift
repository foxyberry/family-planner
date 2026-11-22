import AppCore
import ComposableArchitecture
import DesignSystem
import Domain
import Home
import HolidayProvider
import JourneyWorld
import KitArt
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

/// The home through a whole day, every 15 minutes, for the UX review (skill ux-review): pictures, not
/// a test of them. It runs only from `make ux-sweep`, which sets UX_SWEEP_DIR, and writes, per day:
/// - `frames/<day>/<HHMM>.png`: the bare screens, named by the time only (for the screen-only reviewer);
/// - `<day>-sheet.png`: all frames on one sheet, each labelled with its time and states (for design);
/// - `states.tsv`: day, time, Kid A block, its end, E1's Next row, Kid B's Now and Next.
/// Each frame is the app's own launch in a journey World at that minute, drawn by the real AppView at
/// the 13-inch size. The sample family, plus a one-kid family for E1 (one kid's leave morning).
@MainActor
final class HomeSweepTests: XCTestCase {
    private struct SweepDay {
        var name: String
        var date: String
        var oneKid = false
        var holiday = false
    }

    /// A school day, a Saturday, a public holiday on a weekday, and the school day with one kid.
    private static let days = [
        SweepDay(name: "school-day", date: "2026-11-10"),
        SweepDay(name: "saturday", date: "2026-11-14"),
        SweepDay(name: "holiday", date: "2026-11-09", holiday: true),
        SweepDay(name: "one-kid-school-day", date: "2026-11-10", oneKid: true),
    ]
    private static let size = CGSize(width: 1376, height: 1032)
    private static let step = 15

    func testHomeThroughTheDay() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let out = environment["UX_SWEEP_DIR"] else {
            throw XCTSkip("the home sweep runs only from make ux-sweep (UX_SWEEP_DIR)")
        }
        XCTAssertTrue(FontRegistrar.registerAll(), "Playpen Sans did not register")
        let root = URL(fileURLWithPath: out)
        var states = ["day\ttime\tkid A block\tkid A end\tE1 next\tkid B now\tkid B next"]
        for day in Self.days {
            let frames = root.appendingPathComponent("frames/\(day.name)")
            try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
            var sheet: [(label: String, image: UIImage)] = []
            for minute in stride(from: 0, to: 1440, by: Self.step) {
                let time = String(format: "%02d:%02d", minute / 60, minute % 60)
                let (state, world) = await opened(day, at: time)
                let image = try await render(state, world, day: day)
                try image.pngData()?.write(to: frames.appendingPathComponent(time.replacingOccurrences(of: ":", with: "") + ".png"))
                let line = Self.describe(state.home)
                states.append("\(day.name)\t\(time)\t\(line.joined(separator: "\t"))")
                sheet.append(("\(time)  A: \(line[0]) / \(line[1])\(line[2] == "-" ? "" : "  E1 next: \(line[2])")\nB: \(line[3]) → \(line[4])", image))
            }
            try Self.contactSheet(sheet).pngData()?.write(to: root.appendingPathComponent("\(day.name)-sheet.png"))
        }
        try states.joined(separator: "\n").appending("\n")
            .write(to: root.appendingPathComponent("states.tsv"), atomically: true, encoding: .utf8)
    }

    /// The state at `time`, reached as the app does: the store is read once, then the home loads.
    private func opened(_ day: SweepDay, at time: String) async -> (AppFeature.State, World) {
        var data = WorldData.standard
        data.family = "sample"
        data.now = "\(day.date)T\(time)"
        let world = World(data)
        if day.oneKid { world.family.withValue { $0.kids = Array($0.kids.prefix(1)) } }
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            self.install(world, day: day, into: &$0)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        await store.send(.home(.task))
        await store.receive(\.home.loaded)
        var state = store.state
        state.scenePhase = .active
        return (state, world)
    }

    private func install(_ world: World, day: SweepDay, into values: inout DependencyValues) {
        world.install(&values)
        if day.holiday {
            let parts = day.date.split(separator: "-").compactMap { Int($0) }
            let holiday = Holiday(day: Day(year: parts[0], month: parts[1], day: parts[2]), name: "Example holiday")
            values.holidays.holidays = { _ in [holiday] }
        }
    }

    private func render(_ state: AppFeature.State, _ world: World, day: SweepDay) async throws -> UIImage {
        let store = Store(initialState: state) { AppFeature() } withDependencies: { self.install(world, day: day, into: &$0) }
        let view = AppView(store: store)
            .environment(\.kitArt, BundledKitArt())
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .environment(\.scenePhase, .active)
            .frame(width: Self.size.width, height: Self.size.height)
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 1),
                                                    UITraitCollection(userInterfaceStyle: .light)])
        let strategy = Snapshotting<AnyView, UIImage>.image(
            layout: .fixed(width: Self.size.width, height: Self.size.height), traits: traits)
        return await withCheckedContinuation { done in
            strategy.snapshot(AnyView(view)).run { done.resume(returning: $0) }
        }
    }

    /// Kid A's block case, its end, E1's Next row, Kid B's Now and Next (titles, or "-").
    private static func describe(_ home: HomeFeature.State) -> [String] {
        let block: String = switch home.kidABlock {
        case .leave: "leave"
        case .bedTime: "bedTime"
        case let .next(item): "next(\(item.title))"
        case let .tomorrow(item): "tomorrow(\(item.title))"
        case .nothing: "nothing"
        }
        return [block, "\(home.kidAEnd)", home.leaveNext?.title ?? "-",
                home.kidB?.now.title ?? "-", home.kidB?.next?.title ?? "-"]
    }

    /// Frames at a quarter size, 8 to a row, each with its label above.
    private static func contactSheet(_ frames: [(label: String, image: UIImage)]) -> UIImage {
        let columns = 8
        let thumb = CGSize(width: size.width / 4, height: size.height / 4)
        let labelHeight: CGFloat = 34
        let cell = CGSize(width: thumb.width + 8, height: thumb.height + labelHeight + 8)
        let rows = (frames.count + columns - 1) / columns
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cell.width * CGFloat(columns),
                                                            height: cell.height * CGFloat(rows)), format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                                                             .foregroundColor: UIColor.black]
            for (index, frame) in frames.enumerated() {
                let origin = CGPoint(x: CGFloat(index % columns) * cell.width + 4, y: CGFloat(index / columns) * cell.height + 4)
                (frame.label as NSString).draw(in: CGRect(x: origin.x, y: origin.y, width: thumb.width, height: labelHeight),
                                               withAttributes: attributes)
                frame.image.draw(in: CGRect(origin: CGPoint(x: origin.x, y: origin.y + labelHeight), size: thumb))
            }
        }
    }
}
