import Foundation
import SwiftSyntax

/// Views hold no values (CLAUDE.md, `check-view-values.sh`): view code has no `??` fallback, and
/// screen code has no ternary whose condition reads State or nil. The places match the regex guard:
/// - a `*View.swift` file: the whole file is view code (modifiers, styles, helpers too);
/// - DesignSystem part folders (Clock, Content, Controls, Screens): the whole file, `??` only
///   (parts lay out their own options, so their ternaries are fine);
/// - other DesignSystem files (Layout, Tokens, Fonts): not view code;
/// - any other file: the code inside a type that declares `View` (struct or extension);
/// - never: ios/App, ios/DebugTools, the gallery, tests and snapshot tests.
/// Unlike the regex, it can tell a view's code from a model's in the same file, and a `?` in a
/// string from an operator.
@SwiftSyntaxRule(foldExpressions: true)
struct ViewValuesRule: Rule {
    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "view_values",
        name: "View Values",
        description: "Views hold no values: no ?? fallback and no ternary on State or nil in view code",
        kind: .idiomatic,
        nonTriggeringExamples: [
            Example(code: "struct A: View { var body: some View { Text(store.title) } }"),
            Example(code: "struct Model { var title: String { name ?? \"\" } }"),
            Example(code: "struct A: View { var body: some View { Text(\"a ? b : c\") } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(isOn ? 1 : 0) } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(restore ? 1 : 0) } }"),
        ],
        triggeringExamples: [
            Example(code: "struct A: View { var body: some View { Text(store.label ↓?? \"\") } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(↓store.canUndo ? 1 : 0.45) } }"),
            Example(code: "extension A: View { var inset: CGFloat { ↓caption == nil ? 0 : 8 } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(↓!store.isOn ? 1 : 0) } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(↓a && store.isOn ? 1 : 0) } }"),
            Example(code: "struct A: View { var body: some View { Toggle(isOn: ↓$store.on ? a : b) } }"),
        ]
    )
}

/// Where a file's code counts as view code, from its path.
enum ViewScope {
    case none
    case wholeFile(ternaries: Bool)
    case viewTypes

    /// A path from its last `/ios/` on ("ios/Features/…"), so the folders above the checkout (a
    /// `Tests` folder in the home directory, say) never change the answer; nil outside ios/.
    static func repoPath(_ path: String) -> String? {
        guard let ios = path.range(of: "/ios/", options: .backwards) else { return nil }
        return "ios/" + path[ios.upperBound...]
    }

    init(path: String?) {
        guard let path else {
            self = .viewTypes  // SwiftLint's own examples have no file
            return
        }
        guard let file = Self.repoPath(path) else {
            self = .none
            return
        }
        let skipped = ["ios/App/", "ios/DebugTools/", "ios/DesignSystem/Gallery/"]
        if skipped.contains(where: file.hasPrefix) || file.contains("/Tests/") || file.contains("/SnapshotTests/") {
            self = .none
        } else if ["Clock", "Content", "Controls", "Screens"].contains(where: { file.hasPrefix("ios/DesignSystem/\($0)/") }) {
            self = .wholeFile(ternaries: false)
        } else if file.hasPrefix("ios/DesignSystem/") {
            self = .none
        } else if file.hasSuffix("View.swift") {
            self = .wholeFile(ternaries: true)
        } else {
            self = .viewTypes
        }
    }

    func covers(_ node: some SyntaxProtocol, ternary: Bool) -> Bool {
        switch self {
        case .none: false
        case .wholeFile(let ternaries): !ternary || ternaries
        case .viewTypes: node.isInsideView
        }
    }
}

private extension ViewValuesRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private lazy var scope = ViewScope(path: file.path?.path)

        override func visitPost(_ node: BinaryOperatorExprSyntax) {
            guard node.operator.text == "??", scope.covers(node, ternary: false) else { return }
            violations.append(node.operator.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: TernaryExprSyntax) {
            guard scope.covers(node, ternary: true) else { return }
            // Any `store`, `$store` or `nil` in the condition, however it is wrapped (`!store.x`,
            // `a && store.x`, `(store.x)`, `caption == nil`).
            let readsStateOrNil = node.condition.tokens(viewMode: .sourceAccurate).contains {
                switch $0.tokenKind {
                case .identifier(let name), .dollarIdentifier(let name): name == "store" || name == "$store"
                case .keyword(.nil): true
                default: false
                }
            }
            guard readsStateOrNil else { return }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}

extension SyntaxProtocol {
    /// Inside a struct or extension that declares `View` conformance (also used by OutsideDataRule).
    var isInsideView: Bool {
        var current = Syntax(self).parent
        while let node = current {
            if let decl = node.as(StructDeclSyntax.self), decl.inheritanceClause?.declaresView == true { return true }
            if let decl = node.as(ExtensionDeclSyntax.self), decl.inheritanceClause?.declaresView == true { return true }
            current = node.parent
        }
        return false
    }
}

extension InheritanceClauseSyntax {
    var declaresView: Bool { inheritedTypes.contains { $0.type.trimmedDescription == "View" } }
}
