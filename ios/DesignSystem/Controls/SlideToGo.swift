import CrayonKit
import KitArt
import Strings
import SwiftUI

/// "Slide to go": a yellow crayon track with the way picture as the handle, always on (missions
/// help but never lock it), green with a tick once it reaches the end. Callers pass the words.
/// Words wrap onto at most two lines and never shrink (0a rule); four columns is the narrowest width.
public struct SlideToGo: View {
    private let idleTitle: String
    private let doneTitle: String
    private let onGo: () -> Void
    private let onUndo: (() -> Void)?
    private let knob: KitSlot
    private let doneKnob: KitSlot?
    @State private var isHeld = false
    @State private var hops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The phase the parent asks for (done once the kid is ready, idle again after an undo or
    /// for the next kid). Drags in between live in `model`.
    private let state: SlideToGoModel.Phase
    @State private var model: SlideToGoModel
    private let handleSize: CGFloat = 80

    /// `onUndo`: dragging the knob back past the middle from done (spec "After the slide").
    /// `knob`: the way picture (bus, car, shoe) or the star sticker for a kid with no outing.
    /// `doneKnob`: when done, this picture without the check (A3r: the crown with no medal).
    public init(state: SlideToGoModel.Phase, idleTitle: String, doneTitle: String,
                knob: KitSlot = .busDouble, doneKnob: KitSlot? = nil, onUndo: (() -> Void)? = nil,
                onGo: @escaping () -> Void) {
        self.knob = knob
        self.doneKnob = doneKnob
        self.onUndo = onUndo
        self.state = state
        _model = State(initialValue: SlideToGoModel(phase: state))
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
            // Done (board A3r): "Ready!" ends 24 before the knob, which sits 86 from the right end.
            .frame(maxWidth: .infinity, alignment: isDone ? .trailing : .center)
            .padding(.leading, isDone ? 0 : handleSize)
            // The capsule's round ends cut in when the words take two lines.
            .padding(.leading, Spacing.m)
            .padding(.trailing, isDone ? 110 : Spacing.l)
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: 96)
            .background {
                CrayonSurface(.capsule, fill: isDone ? CrayonStyle.doneGreen : CrayonStyle.yellowSlider,
                              seed: CrayonStyle.Seed.slider)
            }
            .overlay {
                GeometryReader { geometry in
                    let travel = max(geometry.size.width - handleSize - 16, 1)
                    handle(roll: travel * progress)
                        .frame(maxHeight: .infinity)
                        .offset(x: 8 + travel * progress)
                        .gesture(
                            DragGesture()
                                .onChanged { drag in
                                    isHeld = true
                                    if onUndo != nil, isDone || model.isUndoing {
                                        model.undoDragChanged(progress: 1 + drag.translation.width / travel)
                                    } else {
                                        model.dragChanged(progress: drag.translation.width / travel)
                                    }
                                }
                                .onEnded { _ in
                                    isHeld = false
                                    // Only the snap back (or to the end) animates; during the drag
                                    // the handle follows the finger directly.
                                    if model.isUndoing {
                                        let undone = withAnimation(.spring(duration: 0.3)) { model.undoDragEnded() }
                                        if undone { onUndo?() }
                                        return
                                    }
                                    let went = withAnimation(.spring(duration: 0.3)) { model.dragEnded() }
                                    if went {
                                        hops += 1
                                        onGo()
                                    }
                                }
                        )
                }
            }
        // @State keeps its first value, so a new phase from the parent has to be copied in.
        .onChange(of: state) { _, newState in model.phase = newState }
        .sensoryFeedback(.success, trigger: isDone)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAction(named: L10n.tr("slide.go")) {
            guard !isDone else { return }
            model.phase = .done
            onGo()
        }
    }

    /// The knob: rolls and rocks while held; at the end it hops once and keeps a check badge
    /// (board A3r). Reduce Motion: still.
    @ViewBuilder private func handle(roll: CGFloat) -> some View {
        let prize = isDone ? doneKnob : nil
        RollingKitIcon(prize ?? knob, size: isDone && prize == nil ? handleSize * 0.75 : handleSize, roll: roll,
                       isHeld: isHeld)
            .frame(width: handleSize, height: handleSize)
            .overlay(alignment: .bottomTrailing) {
                if isDone, prize == nil { CheckMark(isDone: true, size: handleSize * 0.45) }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : hops) { view, lift in
                view.offset(y: -lift)
            } keyframes: { _ in
                CubicKeyframe(18, duration: 0.18)
                CubicKeyframe(0, duration: 0.22)
            }
    }

    private var title: String {
        switch model.phase {
        case .idle, .dragging: idleTitle
        case .done: doneTitle
        }
    }

    private var progress: CGFloat {
        switch model.phase {
        case let .dragging(p): CGFloat(p)
        case .done: 1
        case .idle: 0
        }
    }

    private var isDone: Bool { model.phase == .done }
}
