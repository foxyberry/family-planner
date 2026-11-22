import Foundation
import SwiftSyntax

/// Not a check: an inventory for the UX review (`scripts/ux-states.sh`, skill `ux-review`). An enum
/// whose doc comment says `ux-states: <screen>` lists a screen's states; this rule reports each of
/// its cases once, with the boards that case's doc comment starts with ("A1 / A1m / E1: …"). A case
/// whose comment starts any other way has no board, which the review reads as a finding.
/// Runs only from its own config (tools/swiftlint/ux-states.yml), never in `make swiftlint`.
@SwiftSyntaxRule
struct UXStatesRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "ux_states",
        name: "UX States",
        description: "Lists each case of a `ux-states:` enum with the boards its doc comment names",
        kind: .lint,
        nonTriggeringExamples: [
            Example(code: "enum Plain { case a }"),
        ],
        triggeringExamples: [
            Example(code: "/// ux-states: home\nenum Block {\n  /// A1: leave\n  ↓case leave\n}"),
        ]
    )
}

private extension UXStatesRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: EnumDeclSyntax) {
            guard let screen = Self.screen(in: node.leadingTrivia) else { return }
            let name = node.name.text
            for member in node.memberBlock.members {
                guard let decl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
                let boards = Self.boards(in: decl.leadingTrivia)
                for element in decl.elements {
                    violations.append(ReasonedRuleViolation(
                        position: element.positionAfterSkippingLeadingTrivia,
                        reason: "ux-states \(screen) | \(name).\(element.name.text) | \(boards.joined(separator: ", "))"
                    ))
                }
            }
        }

        /// The lines of a `///` doc comment, without the slashes.
        static func docLines(_ trivia: Trivia) -> [String] {
            trivia.compactMap { piece -> String? in
                guard case let .docLineComment(text) = piece else { return nil }
                return String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }

        static func screen(in trivia: Trivia) -> String? {
            for line in docLines(trivia) {
                guard let range = line.range(of: "ux-states:") else { continue }
                return line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            }
            return nil
        }

        /// "A1 / A1m / E1: …" → ["A1", "A1m", "E1"]; any other first line → [].
        static func boards(in trivia: Trivia) -> [String] {
            guard let first = docLines(trivia).first, let colon = first.firstIndex(of: ":") else { return [] }
            let names = first[..<colon].split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            return names.allSatisfy(isBoard) ? names : []
        }

        /// A board id: a capital letter, a digit, then letters, digits or dashes (A1, E3b, A2t-w, G1c).
        static func isBoard(_ name: String) -> Bool {
            let chars = Array(name)
            guard chars.count >= 2, chars[0].isUppercase, chars[0].isLetter, chars[1].isNumber else { return false }
            return chars.dropFirst(2).allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }
}
