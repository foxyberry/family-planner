import ComposableArchitecture
import Domain

/// The school lists first-run setup searches (S2) and where their data comes from (Data sources).
/// Features use this interface; the app injects the bundled lists (`SchoolDirectoryLive`).
@DependencyClient
public struct SchoolDirectory: Sendable {
    /// Every school, MOE and (in a private build) international, in no particular order.
    public var schools: @Sendable () async -> [SchoolEntry] = { [] }
    /// The open-data notices the licences ask the app to show.
    public var sources: @Sendable () async -> [DataSource] = { [] }
}

/// One data set and the notice its licence asks for (data.gov.sg, OneMap).
public struct DataSource: Equatable, Identifiable, Sendable {
    public var name: String
    public var attribution: String
    public var licenceURL: String
    public var id: String { name }

    public init(name: String, attribution: String, licenceURL: String) {
        self.name = name
        self.attribution = attribution
        self.licenceURL = licenceURL
    }
}

extension SchoolDirectory: TestDependencyKey {
    public static let testValue = Self()

    /// Made-up schools for previews (privacy rule: no real school is the family's).
    public static let previewValue = Self(
        schools: {
            [
                SchoolEntry(id: "example-primary", name: "Example Primary School", kind: .moe(.primary), // copy-ok: preview data
                            area: "Example Town", hasPrimary: true, followsMoeTerms: true, // copy-ok: preview data
                            hours: SchoolHours(start: 450, end: 810, checked: Day(year: 2026, month: 11, day: 9)),
                            searchKeys: ["example primary"]),
                SchoolEntry(id: "example-international", name: "Example International School", // copy-ok: preview data
                            kind: .other(curriculum: "IB PYP"), area: nil, hasPrimary: true, followsMoeTerms: false,
                            hours: nil, breakCount: 3, searchKeys: ["eis"]),
            ]
        },
        sources: {
            [DataSource(name: "Example data", attribution: "Contains example information.", // copy-ok: preview data
                        licenceURL: "https://example.com/licence")]
        }
    )
}

extension DependencyValues {
    public var schoolDirectory: SchoolDirectory {
        get { self[SchoolDirectory.self] }
        set { self[SchoolDirectory.self] = newValue }
    }
}
