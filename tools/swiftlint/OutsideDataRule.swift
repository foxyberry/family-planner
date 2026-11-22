import Foundation
import SwiftSyntax

/// Outside data reaches the app only through TCA dependencies (CLAUDE.md "Module rules"), so the
/// reference time zone and the time machine apply everywhere and tests can pin them. Replaces the
/// old line regex guard (scripts/check-dependencies.sh, removed), which also matched strings.
/// - A global read: `Date()`, `Date.now`, `Calendar` / `TimeZone` / `Locale` `.current` or
///   `.autoupdatingCurrent`, `UIDevice.current`, `Bundle.main`, `UserDefaults.standard`,
///   `ProcessInfo.processInfo`.
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
        ],
        triggeringExamples: [
            Example(code: "let now = ↓Date()"),
            Example(code: "let calendar = ↓Calendar.current"),
            Example(code: "let zone = ↓TimeZone.autoupdatingCurrent"),
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

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private lazy var scope = OutsideDataScope(path: file.path?.path)

        private var checked: Bool {
            if case .checked = scope { return true }
            return false
        }

        private func global(_ position: AbsolutePosition) {
            violations.append(ReasonedRuleViolation(
                position: position,
                reason: "global read: take it from a dependency (\\.date, \\.calendar, ...) in the reducer"
            ))
        }

        // `Calendar.current`, `Date.now`, `Bundle.main`, ...
        override func visitPost(_ node: MemberAccessExprSyntax) {
            guard checked, let base = node.base?.as(DeclReferenceExprSyntax.self),
                  OutsideDataRule.globals[base.baseName.text]?.contains(node.declName.baseName.text) == true
            else { return }
            global(node.positionAfterSkippingLeadingTrivia)
        }

        // `Date()` with no arguments and no trailing closure.
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard checked, node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Date",
                  node.arguments.isEmpty, node.trailingClosure == nil
            else { return }
            global(node.positionAfterSkippingLeadingTrivia)
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
