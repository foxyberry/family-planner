#if DEBUG
import CoreGraphics
import Foundation
import Synchronization

/// A pretend clock: it reads `anchor` at the real moment `realAnchor` and runs `speed` times as fast.
public struct TimeTravel: Codable, Equatable, Sendable {
    public var anchor: Date
    public var realAnchor: Date
    public var speed: Double

    public init(anchor: Date, realAnchor: Date, speed: Double) {
        self.anchor = anchor
        self.realAnchor = realAnchor
        self.speed = speed
    }

    /// The time the app sees: the real time when not travelling.
    public static func now(setting: TimeTravel?, realNow: Date) -> Date {
        guard let setting else { return realNow }
        return setting.anchor.addingTimeInterval(realNow.timeIntervalSince(setting.realAnchor) * setting.speed)
    }

    /// The same pretend time from now on, at another speed.
    public func withSpeed(_ speed: Double, realNow: Date) -> TimeTravel {
        TimeTravel(anchor: Self.now(setting: self, realNow: realNow), realAnchor: realNow, speed: speed)
    }
}

/// `-fpNow 2026-11-09T07:30 -fpSpeed 60` on the launch command line (`make run NOW=… SPEED=…`).
public struct LaunchOptions: Equatable, Sendable {
    public var now: Date?
    public var speed: Double?
    /// `-fpGrid` (`make device GRID=1`): show the board lines over every screen.
    public var grid = false
    /// `-fpSkipFaceID` (`make run SKIP_FACE_ID=1`): turn "Skip Face ID" on. It only works where the
    /// switch exists (a simulator); a real iPad still asks for Face ID.
    public var skipsFaceID = false

    public init(now: Date?, speed: Double?, grid: Bool = false) {
        self.now = now
        self.speed = speed
        self.grid = grid
    }

    public init(arguments: [String], calendar: Calendar) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        now = value(after: "-fpNow").flatMap(formatter.date(from:))
        speed = value(after: "-fpSpeed").flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil }
        grid = arguments.contains("-fpGrid")
        skipsFaceID = arguments.contains("-fpSkipFaceID")
    }
}

/// Where the debug bubble rests: against the left or right edge, at a share of the screen height,
/// either whole or tucked half off the screen.
public struct BubbleDock: Codable, Equatable, Sendable {
    public enum Side: String, Codable, Sendable { case leading, trailing }

    /// Gap between a resting bubble and the screen edge.
    public static let inset: CGFloat = 16

    public var side: Side
    public var heightShare: CGFloat
    public var tucked: Bool

    public init(side: Side = .trailing, heightShare: CGFloat = 0.8, tucked: Bool = false) {
        self.side = side
        self.heightShare = heightShare
        self.tucked = tucked
    }

    /// Where a dragged bubble settles: the nearer side, tucked when it was pushed into the edge.
    public init(drop: CGPoint, screen: CGSize, size: CGFloat) {
        side = drop.x < screen.width / 2 ? .leading : .trailing
        let edgeDistance = side == .leading ? drop.x : screen.width - drop.x
        tucked = edgeDistance < size / 2
        heightShare = screen.height > 0 ? drop.y / screen.height : 0.5
    }

    public func center(in screen: CGSize, size: CGFloat) -> CGPoint {
        let whole = Self.inset + size / 2
        let x: CGFloat = switch (side, tucked) {
        case (.leading, true): 0
        case (.leading, false): whole
        case (.trailing, true): screen.width
        case (.trailing, false): screen.width - whole
        }
        let y = min(max(heightShare * screen.height, whole), screen.height - whole)
        return CGPoint(x: x, y: y)
    }
}

/// Everything the debug menu can change. Saved in UserDefaults, so it survives `make device` reinstalls.
public struct DebugSettings: Codable, Equatable, Sendable {
    public var time: TimeTravel?
    public var showsLayoutGrid = false
    public var skipsFaceID = false
    public var bubble = BubbleDock()
    /// Spec "Picture rigs": the debug "Rig scale" slider (1.0–1.5); `nil` keeps the kit data's scale.
    public var rigScale: Double?

    public init() {}

    static let key = "fp.debug.settings"

    public static func load(from defaults: UserDefaults) -> DebugSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(DebugSettings.self, from: data) else { return DebugSettings() }
        return settings
    }

    public static func save(_ settings: DebugSettings, to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
    }

    /// Launch arguments win over the saved time: a new `-fpNow` starts from that moment.
    public mutating func apply(_ options: LaunchOptions, realNow: Date) {
        if options.grid { showsLayoutGrid = true }
        if options.skipsFaceID { skipsFaceID = true }
        if let now = options.now {
            time = TimeTravel(anchor: now, realAnchor: realNow, speed: options.speed ?? 1)
        } else if let speed = options.speed {
            time = (time ?? TimeTravel(anchor: realNow, realAnchor: realNow, speed: 1)).withSpeed(speed, realNow: realNow)
        }
    }
}

/// The settings as the rest of the app reads them, from any thread (`\.date`, Face ID).
public final class DebugCore: Sendable {
    private let settings: Mutex<DebugSettings>
    private let realNow: @Sendable () -> Date

    public init(settings: DebugSettings, realNow: @escaping @Sendable () -> Date = { Date() }) {
        self.settings = Mutex(settings)
        self.realNow = realNow
    }

    public func now() -> Date {
        let time = settings.withLock { $0.time }
        return TimeTravel.now(setting: time, realNow: realNow())
    }

    public func realDate() -> Date { realNow() }

    public var skipsFaceID: Bool { settings.withLock { $0.skipsFaceID } }

    public func update(_ new: DebugSettings) { settings.withLock { $0 = new } }
}
#endif
