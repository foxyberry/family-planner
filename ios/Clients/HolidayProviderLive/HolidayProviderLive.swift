import Domain
import Foundation
import HolidayProvider

extension HolidayProvider {
    /// The bundled Singapore public holiday list (`Resources/sg-public-holidays.json`).
    public static let live: HolidayProvider = {
        let all = BundledHolidays.load()
        return HolidayProvider(holidays: { year in all.filter { $0.day.year == year } })
    }()
}

private enum BundledHolidays {
    private struct Entry: Decodable {
        let date: String
        let name: String
    }

    static func load() -> [Holiday] {
        guard let url = bundle()?.url(forResource: "sg-public-holidays", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries.compactMap { entry in
            let parts = entry.date.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return Holiday(day: Day(year: parts[0], month: parts[1], day: parts[2]), name: entry.name)
        }
    }

    /// The resource bundle sits next to this module's code: in the app, or in a test bundle.
    private static func bundle() -> Bundle? {
        [Bundle(for: Token.self), .main].lazy
            .compactMap { $0.url(forResource: "HolidayProviderResources", withExtension: "bundle") }
            .compactMap(Bundle.init(url:))
            .first
    }

    private final class Token {}
}
