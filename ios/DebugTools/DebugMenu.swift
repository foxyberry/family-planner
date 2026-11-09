#if DEBUG
import SwiftUI
import UIKit

/// The debug bubble's menu: time machine, layout, flags, network and build info.
struct DebugMenu: View {
    @Bindable var model: DebugModel
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Date
    @State private var isConfirmingSample = false

    init(model: DebugModel) {
        self.model = model
        _picked = State(initialValue: model.core.now())
    }

    private static let speeds: [Double] = [1, 10, 60, 600]

    var body: some View {
        NavigationStack {
            Form {
                timeSection
                Section("Layout") {
                    Toggle("12-column grid and bands", isOn: $model.settings.showsLayoutGrid)
                }
                Section {
                    LabeledContent("Rig scale", value: String(format: "%.1f", model.rigScale))
                    Slider(value: Binding(get: { model.rigScale }, set: { model.settings.rigScale = $0 }),
                           in: 1.0...1.5, step: 0.1)
                } header: {
                    Text("Pictures")
                } footer: {
                    Text("How far a tapped slot's picture moves on the kid clock. The kit default is 1.5.")
                }
                Section {
                    if model.allowsSkipFaceID {
                        Toggle("Skip Face ID", isOn: $model.settings.skipsFaceID)
                    } else {
                        Text("Skip Face ID works on a simulator only.").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Flags")
                } footer: {
                    Text("Skip Face ID: holding the clock opens grown-up screens without the check.")
                }
                Section {
                    Button("Load sample family", role: .destructive) { isConfirmingSample = true }
                    if model.sampleFamilyFailed {
                        Text("Couldn't write the store. Try again.").foregroundStyle(.red)
                    }
                } header: {
                    Text("Family")
                } footer: {
                    Text("Kid A and Kid B with the seed days, items and missions. This replaces everything on this iPad.")
                }
                .confirmationDialog("Replace your family with the sample family?", isPresented: $isConfirmingSample,
                                    titleVisibility: .visible) {
                    Button("Replace", role: .destructive) {
                        Task {
                            await model.loadSampleFamily()
                            if !model.sampleFamilyFailed { dismiss() }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Everything you entered here is deleted.")
                }
                Section("Network") {
                    Text("No network clients yet. Bus arrivals (M3) will log their requests here.")
                        .foregroundStyle(.secondary)
                }
                buildSection
                Section {
                    Button("Tuck the bubble away") {
                        model.settings.bubble.tucked = true
                        dismiss()
                    }
                }
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var timeSection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                LabeledContent(model.isTravelling ? "App time" : "Real time") {
                    Text(model.core.now(), format: .dateTime.weekday(.wide).day().month().hour().minute().second())
                        .monospacedDigit()
                }
            }
            DatePicker("Go to", selection: $picked)
            Button("Go to this time") { model.travel(to: picked) }
            HStack {
                preset("Today 7:00", day: 0, hour: 7, minute: 0)
                preset("Tomorrow 7:00", day: 1, hour: 7, minute: 0)
                preset("Today 15:30", day: 0, hour: 15, minute: 30)
                preset("Today 23:58", day: 0, hour: 23, minute: 58)
            }
            Picker("Speed", selection: Binding(
                get: { model.settings.time?.speed ?? 1 },
                set: { model.setSpeed($0) }
            )) {
                ForEach(Self.speeds, id: \.self) { Text("×\(Int($0))").tag($0) }
            }
            .pickerStyle(.segmented)
            if model.isTravelling {
                Button("Back to real time", role: .destructive) {
                    model.backToRealTime()
                    picked = model.core.now()
                }
            }
        } header: {
            Text("Time machine")
        } footer: {
            Text("Only the app's clock moves; the 2-minute grown-up lock still counts real seconds. Launch with make run NOW=2026-11-09T07:30 SPEED=60.")
        }
    }

    private func preset(_ title: String, day: Int, hour: Int, minute: Int) -> some View {
        Button(title) {
            let date = model.preset(dayOffset: day, hour: hour, minute: minute)
            model.travel(to: date)
            picked = date
        }
        .buttonStyle(.bordered)
    }

    private var buildSection: some View {
        let info = Bundle.main.infoDictionary ?? [:]
        return Section("Build") {
            LabeledContent("Version", value: "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))")
            LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "?")
            LabeledContent("Device", value: "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)")
            LabeledContent("Time zone", value: model.calendar.timeZone.identifier)
        }
    }
}
#endif
