import Foundation
import SwiftSyntax

/// Spec "Layout model": screens fill layout slots with parts and rows; they carry no numbers and no
/// offsets (replaces the line regex guard scripts/check-layout-literals.sh, removed, which missed a
/// number on a call's second line). In a screen file
/// (a `*View.swift` file under ios/Features or ios/AppCore, tests aside) it reports:
/// - any `.offset(…)`;
/// - a non-zero number literal inside `.frame(…)` or `.padding(…)`, or in a `spacing:` argument;
/// - a non-zero number literal passed as a size: `height:`, `width:`, `minHeight:`, `maxHeight:`,
///   `minWidth:`, `maxWidth:`, `labelHeight:` (2026-11-21: `SetupRow(height: 72)` kept the 13"
///   height while its parts scaled).
/// Use a token, a part's scaled size (`sizing.fieldHeight`) or a layout. Files that still have some
/// are counted against scripts/layout-literals-pending.txt by scripts/swiftlint.sh (one count per
/// line, shrink only), so this rule runs from its own pass there.
@SwiftSyntaxRule
struct LayoutLiteralsRule: Rule {
    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "layout_literals",
        name: "Layout Literals",
        description: "Screens carry no layout numbers and no offsets: use tokens, parts' scaled sizes or layouts",
        kind: .style,
        nonTriggeringExamples: [
            Example(code: ".frame(width: sizing.swatch2, height: layout.row)"),
            Example(code: "HStack(spacing: Spacing.sm) {}"),
            Example(code: "ListRow(leading: x, minHeight: 0) {}"),
        ],
        triggeringExamples: [
            Example(code: "Text(\"a\").↓offset(x: 20, y: -20)"),
            Example(code: ".frame(width: ↓112)"),
            Example(code: "SetupRow(label: day, height: ↓72) {}"),
        ]
    )
}

private extension LayoutLiteralsRule {
    static let layoutCalls: Set<String> = ["frame", "padding"]
    static let sizeLabels: Set<String> = ["height", "width", "minHeight", "maxHeight", "minWidth", "maxWidth", "labelHeight"]

    /// A screen file: `*View.swift` under ios/Features or ios/AppCore, not in tests. SwiftLint's own
    /// examples (no file) count as screens.
    static func isScreen(_ path: String?) -> Bool {
        guard let path else { return true }
        guard let file = ViewScope.repoPath(path), file.hasSuffix("View.swift"), !file.contains("/Tests/") else { return false }
        return file.hasPrefix("ios/Features/") || file.hasPrefix("ios/AppCore/")
    }

    /// A number literal that isn't zero.
    static func nonZero(_ node: some SyntaxProtocol) -> Bool {
        if let int = node.as(IntegerLiteralExprSyntax.self) {
            return Int(int.literal.text.replacingOccurrences(of: "_", with: "")) != 0
        }
        if let float = node.as(FloatLiteralExprSyntax.self) {
            return Double(float.literal.text.replacingOccurrences(of: "_", with: "")) != 0
        }
        return false
    }

    /// The modifier or initializer a call names: `.frame(…)`, `view.padding(…)` → "frame", "padding".
    static func calledName(_ call: FunctionCallExprSyntax) -> String? {
        call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private lazy var screen = LayoutLiteralsRule.isScreen(file.path?.path)

        private func report(_ node: some SyntaxProtocol, _ what: String) {
            violations.append(ReasonedRuleViolation(
                position: node.positionAfterSkippingLeadingTrivia,
                reason: "layout literal in a screen (\(what)): use a token, part or layout; no offsets"
            ))
        }

        // `.offset(x:y:)`
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard screen, let member = node.calledExpression.as(MemberAccessExprSyntax.self),
                  member.declName.baseName.text == "offset" else { return }
            report(member.declName, "offset")
        }

        override func visitPost(_ node: IntegerLiteralExprSyntax) { check(node) }
        override func visitPost(_ node: FloatLiteralExprSyntax) { check(node) }

        /// A non-zero number in a `.frame` / `.padding` call, a `spacing:` argument or a size label.
        private func check(_ literal: some SyntaxProtocol) {
            guard screen, LayoutLiteralsRule.nonZero(literal) else { return }
            // A size label takes the number itself: `height: 72` (not `height: layout.row + 8`).
            if let argument = literal.parent?.as(LabeledExprSyntax.self), let label = argument.label?.text,
               LayoutLiteralsRule.sizeLabels.contains(label) {
                return report(literal, "\(label):")
            }
            // Walk out to the enclosing call; it counts only if the number is in its arguments, not
            // in the view it is chained onto (`PaperCard(seed: 52) { … }.frame(…)`: 52 is a seed).
            var child = Syntax(literal)
            var current = literal.parent
            while let node = current {
                if let argument = node.as(LabeledExprSyntax.self), argument.label?.text == "spacing" {
                    return report(literal, "spacing:")
                }
                if let call = node.as(FunctionCallExprSyntax.self), child.id == Syntax(call.arguments).id,
                   let name = LayoutLiteralsRule.calledName(call), LayoutLiteralsRule.layoutCalls.contains(name) {
                    return report(literal, ".\(name)")
                }
                // Stop at the statement or a closure: a number further out is not this call's.
                if node.is(CodeBlockItemSyntax.self) || node.is(MemberBlockItemSyntax.self) || node.is(ClosureExprSyntax.self) {
                    return
                }
                child = node
                current = node.parent
            }
        }
    }
}
