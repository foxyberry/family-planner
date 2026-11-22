import Foundation
import SwiftSyntax

/// Views hold no values (CLAUDE.md, `check-view-values.sh`): inside a `View`, no `??` fallback, and
/// in screens no ternary on State or on nil (DesignSystem parts lay out their own options, so their
/// ternaries are fine). The first native rule: the regex guard can't tell a view's code from a
/// model's in the same file, or a `?` in a string from an operator.
@SwiftSyntaxRule(foldExpressions: true)
struct ViewValuesRule: Rule {
    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "view_values",
        name: "View Values",
        description: "Views hold no values: no ?? fallback and no ternary on State or nil inside a View",
        kind: .idiomatic,
        nonTriggeringExamples: [
            Example(code: "struct A: View { var body: some View { Text(store.title) } }"),
            Example(code: "struct Model { var title: String { name ?? \"\" } }"),
            Example(code: "struct A: View { var body: some View { Text(\"a ? b : c\") } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(isOn ? 1 : 0) } }"),
        ],
        triggeringExamples: [
            Example(code: "struct A: View { var body: some View { Text(store.label ↓?? \"\") } }"),
            Example(code: "struct A: View { var body: some View { Rect().opacity(↓store.canUndo ? 1 : 0.45) } }"),
            Example(code: "extension A: View { var inset: CGFloat { ↓caption == nil ? 0 : 8 } }"),
        ]
    )
}

private extension ViewValuesRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: BinaryOperatorExprSyntax) {
            guard node.operator.text == "??", node.isInsideView else { return }
            violations.append(node.operator.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: TernaryExprSyntax) {
            guard node.isInsideView, file.path?.path.contains("/ios/DesignSystem/") != true else { return }
            let condition = node.condition.trimmedDescription
            guard condition.hasPrefix("store.") || condition.contains("== nil") || condition.contains("!= nil") else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}

private extension SyntaxProtocol {
    /// Inside a struct or extension that declares `View` conformance.
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

private extension InheritanceClauseSyntax {
    var declaresView: Bool { inheritedTypes.contains { $0.type.trimmedDescription == "View" } }
}
