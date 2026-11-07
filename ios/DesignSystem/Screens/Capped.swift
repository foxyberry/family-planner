/// Kid screens never scroll: lists are cut to a fixed count and the rest shown as "+N".
public struct Capped<Element> {
    public let visible: [Element]
    public let overflow: Int

    public init(_ items: [Element], max: Int) {
        let limit = Swift.max(max, 0)
        visible = Array(items.prefix(limit))
        overflow = Swift.max(items.count - limit, 0)
    }
}

extension Capped: Equatable where Element: Equatable {}
extension Capped: Sendable where Element: Sendable {}
