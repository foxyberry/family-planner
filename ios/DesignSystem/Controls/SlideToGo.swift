import CrayonKit
import KitArt
import Strings
import SwiftUI

/// "Slide to go": a yellow crayon track with the bus as the handle. Locked (dim) until the
/// morning steps are done, green with a tick once it reaches the end. Callers pass the words.
/// Words wrap onto at most two lines and never shrink (0a rule); four columns is the narrowest width.
public struct SlideToGo: View {
    private let lockedTitle: String
    private let idleTitle: String
    private let doneTitle: String
    private let onGo: () -> Void
    /// The phase the parent asks for (locked → idle when the morning steps are done, idle again
    /// the next morning). Drags in between live in `model`.
    private let state: SlideToGoModel.Phase
    @State private var model: SlideToGoModel
    private let handleSize: CGFloat = 80

    public init(state: SlideToGoModel.Phase, lockedTitle: String, idleTitle: String, doneTitle: String,
                onGo: @escaping () -> Void) {
        self.state = state
        _model = State(initialValue: SlideToGoModel(phase: state))
        self.lockedTitle = lockedTitle
        self.idleTitle = idleTitle
        self.doneTitle = doneTitle
        self.onGo = onGo
    }

    public var body: some View {
        // The words set the height (96, taller when they wrap); the handle rides on top.
        Text(title)
            .crayonType(.head)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(CrayonColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.leading, isDone ? 0 : handleSize)
            // The capsule's round ends cut in when the words take two lines.
            .padding(.leading, Spacing.m)
            .padding(.trailing, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: 96)
            .background {
                CrayonSurface(.capsule, fill: isDone ? CrayonStyle.doneGreen : CrayonStyle.yellowSlider,
                              seed: CrayonStyle.Seed.slider)
            }
            .overlay {
                GeometryReader { geometry in
                    let travel = max(geometry.size.width - handleSize - 16, 1)
                    handle
                        .frame(maxHeight: .infinity)
                        .offset(x: 8 + travel * progress)
                        .gesture(
                            DragGesture()
                                .onChanged { model.dragChanged(progress: $0.translation.width / travel) }
                                .onEnded { _ in
                                    // Only the snap back (or to the end) animates; during the drag
                                    // the handle follows the finger directly.
                                    let went = withAnimation(.spring(duration: 0.3)) { model.dragEnded() }
                                    if went { onGo() }
                                }
                        )
                }
            }
        // @State keeps its first value, so a new phase from the parent has to be copied in.
        .onChange(of: state) { _, newState in model.phase = newState }
        .opacity(isLocked ? 0.5 : 1)
        .sensoryFeedback(.success, trigger: isDone)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAction(named: L10n.tr("slide.go")) {
            guard !isLocked, !isDone else { return }
            model.phase = .done
            onGo()
        }
    }

    @ViewBuilder private var handle: some View {
        if isDone {
            CheckMark(isDone: true, size: handleSize)
        } else {
            KitIcon(.busDouble, size: handleSize)
        }
    }

    private var title: String {
        switch model.phase {
        case .locked: lockedTitle
        case .idle, .dragging: idleTitle
        case .done: doneTitle
        }
    }

    private var progress: CGFloat {
        switch model.phase {
        case let .dragging(p): CGFloat(p)
        case .done: 1
        case .idle, .locked: 0
        }
    }

    private var isLocked: Bool { if case .locked = model.phase { true } else { false } }
    private var isDone: Bool { model.phase == .done }
}
