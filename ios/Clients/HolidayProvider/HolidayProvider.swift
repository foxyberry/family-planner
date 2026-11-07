import ComposableArchitecture
import Domain

public struct Holiday: Hashable, Codable, Sendable {
    public var day: Day
    public var name: String

    public init(day: Day, name: String) {
        self.day = day
        self.name = name
    }
}

/// Public holidays. Features use this interface; the app injects the bundled list.
@DependencyClient
public struct HolidayProvider: Sendable {
    /// Holidays in `year`, empty when the year is unknown.
    public var holidays: @Sendable (_ year: Int) async -> [Holiday] = { _ in [] }
}

extension HolidayProvider: TestDependencyKey {
    public static let testValue = Self()
    public static let previewValue = Self(holidays: { _ in [] })
}

extension DependencyValues {
    public var holidays: HolidayProvider {
        get { self[HolidayProvider.self] }
        set { self[HolidayProvider.self] = newValue }
    }
}
