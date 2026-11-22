import Foundation
import SwiftSyntax

/// Outside data reaches the app only through TCA dependencies (CLAUDE.md "Module rules"), so the
/// reference time zone and the time machine apply everywhere and tests can pin them. Replaces the
/// old line regex guard (scripts/check-dependencies.sh, removed), which also matched strings.
/// - A global read: `Date()`, `Date.now`, `Calendar` / `TimeZone` / `Locale` `.current` or
///   `.autoupdatingCurrent`, `UIDevice.current`, `Bundle.main`, `UserDefaults.standard`,
///   `ProcessInfo.processInfo`, with or without a module (`Foundation.Calendar.current`).
///   A read that is right (a resource lookup in the main bundle) says why on its line:
///   `Bundle.main  // outside-ok: resource lookup`.
/// - These member names with the type left out, whatever the type: `.current`,
///   `.autoupdatingCurrent`, `.now`, `.processInfo`, `.main`, `.standard`. SwiftSyntax has no type
///   checker, so `.current` could be any of the globals; write the type (`Calendar.current`,
///   `MarkerStyle.standard`) and the read is either fine or caught above (user, 2026-11-22).
/// - A view reading `@Dependency`: in a `*View.swift` file, or inside a type that declares `View`
///   (a view gets the default value, not the store's).
/// Allowed: ios/App (bootstrap), ios/Clients/*Live (implementations), ios/DebugTools (debug only),
/// tests and snapshot tests.
@SwiftSyntaxRule
struct OutsideDataRule: Rule {
    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "outside_data",
        name: "Outside Data",
        description: "Time, calendar, locale, device, bundle and settings come only from dependencies; views never read @Dependency",
        kind: .lint,
        nonTriggeringExamples: [
            Example(code: "let now = date.now"),
            Example(code: "let label = \"Date() is a global\""),
            Example(code: "let start = Date(timeIntervalSince1970: 0)"),
            Example(code: "struct Feature { @Dependency(\\.date) var date }"),
            Example(code: "let marker = MarkerStyle.standard"),
            Example(code: "let bundles = [Bundle.main]  // outside-ok: resource lookup"),
        ],
        triggeringExamples: [
            Example(code: "let now = ↓Date()"),
            Example(code: "let calendar = ↓Calendar.current"),
            Example(code: "let zone = ↓TimeZone.autoupdatingCurrent"),
            Example(code: "let zone: TimeZone = ↓.current"),
            Example(code: "plan(↓.current)"),
            Example(code: "let marker: MarkerStyle = ↓.standard"),
            Example(code: "struct A: View { ↓@Dependency(\\.date) var date }"),
        ]
    )
}

/// Where outside data may be read, from the path.
enum OutsideDataScope {
    case allowed
    case checked(viewFile: Bool)

    init(path: String?) {
        guard let path else {
            self = .checked(viewFile: false)  // SwiftLint's own examples have no file
            return
        }
        guard let file = ViewScope.repoPath(path) else {
            self = .allowed
            return
        }
        let allowed = file.hasPrefix("ios/App/") || file.hasPrefix("ios/DebugTools/")
            || file.contains("/Tests/") || file.contains("/SnapshotTests/")
            || (file.hasPrefix("ios/Clients/") && file.split(separator: "/").dropFirst(2).first?.hasSuffix("Live") == true)
        self = allowed ? .allowed : .checked(viewFile: file.hasSuffix("View.swift"))
    }
}

private extension OutsideDataRule {
    static let globals: [String: Set<String>] = [
        "Date": ["now"],
        "Calendar": ["current", "autoupdatingCurrent"],
        "TimeZone": ["current", "autoupdatingCurrent"],
        "Locale": ["current", "autoupdatingCurrent"],
        "UIDevice": ["current"],
        "Bundle": ["main"],
        "UserDefaults": ["standard"],
        "ProcessInfo": ["processInfo"],
    ]

    /// Member names that must carry their type: every global's member.
    static let explicitNames: Set<String> = globals.values.reduce(into: []) { $0.formUnion($1) }

    /// The modules these types come from, as a qualifier (`Foundation.Date()`).
    static let modules: Set<String> = ["Foundation", "UIKit", "SwiftUI"]

    /// The type an expression names: `Calendar`, or `Foundation.Calendar` qualified by a module.
    static func typeName(_ expr: ExprSyntax?) -> String? {
        guard let expr else { return nil }
        if let name = expr.as(DeclReferenceExprSyntax.self) { return name.baseName.text }
        if let member = expr.as(MemberAccessExprSyntax.self),
           let module = member.base?.as(DeclReferenceExprSyntax.self), modules.contains(module.baseName.text) {
            return member.declName.baseName.text
        }
        return nil
    }

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private lazy var scope = OutsideDataScope(path: file.path?.path)

        private var checked: Bool {
            if case .checked = scope { return true }
            return false
        }

        /// The line says why this global read is right: `// outside-ok: <reason>`. An end-of-line
        /// comment is the trailing trivia of the line's last token, so walk to it.
        private func justified(_ node: some SyntaxProtocol) -> Bool {
            var token = node.lastToken(viewMode: .sourceAccurate)
            while let current = token {
                for piece in current.trailingTrivia {
                    if case let .lineComment(text) = piece, text.contains("outside-ok:") { return true }
                }
                guard let next = current.nextToken(viewMode: .sourceAccurate),
                      !next.leadingTrivia.contains(where: \.isNewline) else { return false }
                token = next
            }
            return false
        }

        private func global(_ node: some SyntaxProtocol) {
            guard !justified(node) else { return }
            violations.append(ReasonedRuleViolation(
                position: node.positionAfterSkippingLeadingTrivia,
                reason: "global read: take it from a dependency (\\.date, \\.calendar, ...) in the reducer"
            ))
        }

        // `Calendar.current`, `Date.now`, `Bundle.main`, `Foundation.Calendar.current`, ...; and
        // `.current`, `.main`, `.standard`, ... with no type.
        override func visitPost(_ node: MemberAccessExprSyntax) {
            guard checked else { return }
            let name = node.declName.baseName.text
            if node.base == nil {
                guard OutsideDataRule.explicitNames.contains(name) else { return }
                violations.append(ReasonedRuleViolation(
                    position: node.positionAfterSkippingLeadingTrivia,
                    reason: "write the type: `Calendar.current`, `Bundle.main`, `MarkerStyle.standard` (.\(name) could be a global read)"
                ))
            } else if let type = OutsideDataRule.typeName(node.base), OutsideDataRule.globals[type]?.contains(name) == true {
                global(node)
            }
        }

        // `Date()` or `Foundation.Date()` with no arguments and no trailing closure.
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard checked, OutsideDataRule.typeName(node.calledExpression) == "Date",
                  node.arguments.isEmpty, node.trailingClosure == nil
            else { return }
            global(node)
        }

        // `@Dependency(...)` in view code.
        override func visitPost(_ node: AttributeSyntax) {
            guard case let .checked(viewFile) = scope,
                  node.attributeName.trimmedDescription == "Dependency",
                  viewFile || node.isInsideView
            else { return }
            violations.append(ReasonedRuleViolation(
                position: node.positionAfterSkippingLeadingTrivia,
                reason: "view reads @Dependency: put the value in State instead"
            ))
        }
    }
}
