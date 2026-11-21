import AppCore
import ComposableArchitecture
import Foundation
import JourneyWorld
import XCTest

/// The platform-neutral journeys (Driver/journeys/*.json) replayed through the root store with the
/// contract's names only (`AgentContract`): proof that the JSON journeys and the contract run on
/// iOS, the same way a driver on another platform would run them. Where the app's views would send
/// a screen's `task` as it appears, the runner does (`appear`).
@MainActor
final class AgentJourneyTests: XCTestCase {
    func testFirstRunJourneyFile() async throws { try await replay("first-run") }
    func testAddAChildJourneyFile() async throws { try await replay("add-a-child") }

    /// What `ls` lists as each screen's actions (`AgentContract.schema`) is contract.json's, key by
    /// key: names, argument names and argument types.
    func testSchemaMatchesTheContract() throws {
        let runfiles = ProcessInfo.processInfo.environment["TEST_SRCDIR"] ?? ""
        let url = URL(fileURLWithPath: runfiles + "/_main/ios/Journeys/Tests/Driver/contract.json")
        let contract = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var expected: [String: [String: [String: String]]] = [:]
        for screen in contract["screens"] as? [[String: Any]] ?? [] {
            let id = try XCTUnwrap(screen["id"] as? String)
            var actions: [String: [String: String]] = [:]
            for action in screen["actions"] as? [[String: Any]] ?? [] {
                actions[try XCTUnwrap(action["name"] as? String)] = action["args"] as? [String: String] ?? [:]
            }
            expected[id] = actions
        }
        XCTAssertEqual(AgentContract.schema, expected)
    }

    private func replay(_ name: String) async throws {
        let journey = try load(name)
        let world = World(worldData(journey["world"] as? [String: Any] ?? [:]))
        let store = world.store()
        await store.send(.checkFamily)
        await settle(store, setupBefore: true, pathBefore: [])

        for (index, step) in (journey["steps"] as? [[String: Any]] ?? []).enumerated() {
            let label = "\(name) step \(index + 1)"
            if let action = step["do"] as? String {
                let shown = AgentContract.ls(store.state)
                let args = (step["args"] as? [String: Any] ?? [:]).mapValues { resolve(value($0), in: shown) }
                switch AgentContract.action(action, args, in: store.state) {
                case let .success(sent):
                    let setupBefore = store.state.setup != nil, pathBefore = Set(store.state.path.ids)
                    await store.send(sent)
                    await settle(store, setupBefore: setupBefore, pathBefore: pathBefore)
                case let .failure(refusal):
                    return XCTFail("\(label): \(action) refused: \(refusal.reason)")
                }
            } else if let expect = step["expect"] as? [String: Any] {
                let shown = AgentContract.ls(store.state)
                for (key, expected) in expect {
                    let actual: AgentValue? = key == "screen" ? .string(shown.screen) : shown.fields[key] ?? shown.app[key]
                    XCTAssertEqual(actual, value(expected), "\(label): \(key) (screen \(shown.screen))")
                }
            }
        }
        await store.skipInFlightEffects(strict: false)
    }

    /// Lets the step's effects finish, then plays what the views would send as screens appear: the
    /// home's `task` once first run is over, and a pushed screen's `task`.
    private func settle(_ store: TestStoreOf<AppFeature>, setupBefore: Bool, pathBefore: Set<StackElementID>) async {
        await store.finish()
        await store.skipReceivedActions(strict: false)
        if store.state.setup != nil, setupBefore, store.state.setup?.directory.isEmpty == true {
            await store.send(.setup(.task))
        } else if setupBefore, store.state.setup == nil {
            await store.send(.home(.task))
        }
        for id in store.state.path.ids where !pathBefore.contains(id) {
            switch store.state.path[id: id] {
            case .settings?: await store.send(.path(.element(id: id, action: .settings(.task))))
            case .ourDay?: await store.send(.path(.element(id: id, action: .ourDay(.task))))
            default: break
            }
        }
        await store.finish()
        await store.skipReceivedActions(strict: false)
    }

    // MARK: - JSON

    private func load(_ name: String) throws -> [String: Any] {
        let runfiles = ProcessInfo.processInfo.environment["TEST_SRCDIR"] ?? ""
        let url = URL(fileURLWithPath: runfiles + "/_main/ios/Journeys/Tests/Driver/journeys/\(name).json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try XCTUnwrap(object as? [String: Any], "\(name).json is not an object")
    }

    private func worldData(_ world: [String: Any]) -> WorldData {
        var data = WorldData.standard
        if let now = world["now"] as? String { data.now = now }
        if let zone = world["timeZone"] as? String { data.timeZone = zone }
        if let family = world["family"] as? String { data.family = family }
        if let faceID = world["faceID"] as? String { data.faceID = faceID }
        return data
    }

    /// `"$field"` takes that field's value from the last `ls`.
    private func resolve(_ value: AgentValue, in shown: AgentScreen) -> AgentValue {
        guard case let .string(text) = value, text.hasPrefix("$") else { return value }
        return shown.fields[String(text.dropFirst())] ?? .null
    }

    private func value(_ any: Any) -> AgentValue { AgentValue(json: any) }
}
