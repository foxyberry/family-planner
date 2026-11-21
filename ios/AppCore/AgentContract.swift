import ComposableArchitecture
import Domain
import Foundation
import Grownup
import Home
import Setup

/// A JSON value in the agent driver's protocol (ios/Journeys/Tests/Driver/PROTOCOL.md).
public enum AgentValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case string(String)
    case list([AgentValue])
    case object([String: AgentValue])
}

/// What `ls` answers: the focused screen, the stack under it and the contract's fields.
public struct AgentScreen: Equatable, Sendable {
    public var screen: String
    public var stack: [String]
    public var fields: [String: AgentValue]
    public var app: [String: AgentValue]
}

/// Why `do` refused an action; nothing changed.
public struct AgentRefusal: Error, Equatable, Sendable {
    public var reason: String
}

/// The parity contract (ios/Journeys/Tests/Driver/contract.json) bound to this app: the screen ids,
/// the visible fields `ls` shows and the person actions `do` sends. Platform-neutral names in, TCA
/// actions out; the driver's transport and the journey runner both go through here.
public enum AgentContract {
    /// `ls`: the focused screen and its contract fields.
    public static func ls(_ state: AppFeature.State) -> AgentScreen {
        let app: [String: AgentValue] = ["relockCaption": text(state.relockCaption)]
        if let setup = state.setup {
            return AgentScreen(screen: "setup", stack: ["setup"], fields: fields(setup), app: app)
        }
        let stack = ["home"] + state.path.map(screenID)
        if let card = state.lockCard {
            return AgentScreen(screen: "lock", stack: stack + ["lock"],
                               fields: ["primary": text(card.primary), "cancel": .string(card.cancel)], app: app)
        }
        guard let top = state.path.last else {
            return AgentScreen(screen: "home", stack: stack, fields: fields(state.home), app: app)
        }
        let topFields: [String: AgentValue]
        switch top {
        case let .settings(settings):
            topFields = ["kids": .list((settings.snapshot?.kids ?? []).map { .string($0.name) })]
        case let .addChild(add):
            topFields = ["name": .string(add.name), "age": .string(add.ageText),
                         "colour": .int(add.colorIndex), "canSave": .bool(add.canSave)]
        default:
            topFields = [:]
        }
        return AgentScreen(screen: screenID(top), stack: stack, fields: topFields, app: app)
    }

    /// `do <screen>.<action> <args>`: the TCA action a person's step becomes, or why it can't be sent.
    public static func action(_ name: String, _ args: [String: AgentValue],
                              in state: AppFeature.State) -> Result<AppFeature.Action, AgentRefusal> {
        let focused = ls(state).screen
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return .failure(AgentRefusal(reason: "unknown action \(name)")) }
        guard parts[0] == focused else { return .failure(AgentRefusal(reason: "not on \(parts[0])")) }
        let mapped: AppFeature.Action?
        switch parts[0] {
        case "setup": mapped = state.setup.flatMap { setupAction(parts[1], args, $0) }.map { .setup($0) }
        case "home": mapped = homeAction(parts[1])
        case "lock": mapped = parts[1] == "primaryTapped" ? .lockPrimaryTapped
            : parts[1] == "cancelTapped" ? .lockCancelTapped : nil
        default: mapped = pathAction(parts[0], parts[1], args, state)
        }
        guard let mapped else { return .failure(AgentRefusal(reason: "unknown action or arguments: \(name)")) }
        return .success(mapped)
    }

    // MARK: - Fields

    private static func fields(_ setup: SetupFeature.State) -> [String: AgentValue] {
        let step: String
        switch setup.step {
        case .family: step = "family"
        case .school: step = "school"
        case .gettingThere: step = "gettingThere"
        case .almostDone: step = "almostDone"
        }
        let kids = setup.kids.map { kid -> AgentValue in
            .object(["name": .string(kid.name), "age": .string(kid.ageText), "face": text(kid.face)])
        }
        let search = setup.goingSearch
        return [
            "step": .string(step),
            "canGoNext": .bool(setup.canGoNext),
            "kids": .list(Array(kids)),
            "removeConfirm": .bool(setup.removeConfirm != nil),
            "school.text": .string(setup.tabKid?.school.text ?? ""),
            "school.picked": text(setup.tabKid?.school.picked?.id),
            "stop.code": .string(search.stop),
            "stop.buses": .list(search.servicesAtStop.map { .string($0) }),
        ]
    }

    private static func fields(_ home: HomeFeature.State) -> [String: AgentValue] {
        [
            "weekday": text(home.weekday.map(weekdayName)),
            "today": text(home.today.map { String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day) }),
            "kids": .list(home.days.map { .string($0.kid.name) }),
        ]
    }

    private static func weekdayName(_ weekday: Weekday) -> String {
        switch weekday {
        case .sunday: "sunday"
        case .monday: "monday"
        case .tuesday: "tuesday"
        case .wednesday: "wednesday"
        case .thursday: "thursday"
        case .friday: "friday"
        case .saturday: "saturday"
        }
    }

    private static func screenID(_ element: AppFeature.Path.State) -> String {
        switch element {
        case .settings: "settings"
        case .editor: "editor"
        case .ourDay: "ourDay"
        case .missionEditor: "missionEditor"
        case .busSettings: "busSettings"
        case .changeBuses: "changeBuses"
        case .schoolEditor: "schoolEditor"
        case .addChild: "addChild"
        case .changeSchool: "changeSchool"
        case .dataSources: "dataSources"
        case .missions: "missions"
        }
    }

    private static func text(_ value: String?) -> AgentValue {
        value.map(AgentValue.string) ?? .null
    }

    // MARK: - Actions

    private static func setupAction(_ name: String, _ args: [String: AgentValue],
                                    _ setup: SetupFeature.State) -> SetupFeature.Action? {
        func kid() -> KidEntry.ID? {
            guard case let .int(index)? = args["kid"], setup.kids.indices.contains(index) else { return nil }
            return setup.kids[index].id
        }
        func string(_ key: String) -> String? {
            guard case let .string(value)? = args[key] else { return nil }
            return value
        }
        func int(_ key: String) -> Int? {
            guard case let .int(value)? = args[key] else { return nil }
            return value
        }
        switch name {
        case "nameChanged": return kid().flatMap { id in string("text").map { .nameChanged(id, $0) } }
        case "ageChanged": return kid().flatMap { id in string("text").map { .ageChanged(id, $0) } }
        case "faceTapped": return kid().flatMap { id in string("face").map { .faceTapped(id, $0) } }
        case "addKidTapped": return .addKidTapped
        case "removeKidTapped": return kid().map { .removeKidTapped($0) }
        case "removeConfirmed": return .removeConfirmed
        case "removeCancelled": return .removeCancelled
        case "nextTapped": return .nextTapped
        case "schoolTextChanged": return string("text").map { .schoolTextChanged($0) }
        case "schoolPicked":
            return string("school").flatMap { id in setup.directory.first { $0.id == id } }.map { .schoolPicked($0) }
        case "wayPicked": return string("way").flatMap(Way.init(rawValue:)).map { .wayPicked($0) }
        case "stopTextChanged": return string("text").map { .stopSearch(.textChanged($0)) }
        case "busTapped": return string("bus").map { .serviceTapped($0) }
        case "walkChanged": return int("minutes").map { .walkChanged($0) }
        default: return nil
        }
    }

    private static func homeAction(_ name: String) -> AppFeature.Action? {
        switch name {
        case "clockHeld": .home(.clockHoldCompleted)
        case "missionsTapped": .home(.missionsTapped)
        default: nil
        }
    }

    private static func pathAction(_ screen: String, _ name: String, _ args: [String: AgentValue],
                                   _ state: AppFeature.State) -> AppFeature.Action? {
        guard let id = state.path.ids.last else { return nil }
        func string(_ key: String) -> String? {
            guard case let .string(value)? = args[key] else { return nil }
            return value
        }
        let element: AppFeature.Path.Action?
        switch (screen, name) {
        case ("ourDay", "settingsTapped"): element = .ourDay(.settingsTapped)
        case ("ourDay", "backTapped"): element = .ourDay(.backTapped)
        case ("settings", "addChildTapped"): element = .settings(.addChildTapped)
        case ("settings", "backTapped"): element = .settings(.backTapped)
        case ("addChild", "nameChanged"): element = string("text").map { .addChild(.binding(.set(\.name, $0))) }
        case ("addChild", "ageChanged"): element = string("text").map { .addChild(.binding(.set(\.ageText, $0))) }
        case ("addChild", "faceTapped"): element = string("face").map { .addChild(.faceTapped($0)) }
        case ("addChild", "saveTapped"): element = .addChild(.saveTapped)
        case ("addChild", "backTapped"): element = .addChild(.backTapped)
        default: element = nil
        }
        return element.map { .path(.element(id: id, action: $0)) }
    }
}

// MARK: - JSON (the driver's wire format)

extension AgentValue {
    /// A value from `JSONSerialization` (numbers that are booleans stay booleans).
    public init(json: Any) {
        switch json {
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID(): self = .bool(number.boolValue)
        case let number as NSNumber: self = .int(number.intValue)
        case let text as String: self = .string(text)
        case let list as [Any]: self = .list(list.map(AgentValue.init(json:)))
        case let object as [String: Any]: self = .object(object.mapValues(AgentValue.init(json:)))
        default: self = .null
        }
    }

    /// The value for `JSONSerialization`.
    public var json: Any {
        switch self {
        case .null: NSNull()
        case let .bool(value): value
        case let .int(value): value
        case let .string(value): value
        case let .list(values): values.map(\.json)
        case let .object(values): values.mapValues(\.json)
        }
    }
}

/// What the driver does with one request: answer it, or send a person action to the store (and then
/// answer with `ls`).
public enum AgentReply {
    case answer(status: Int, json: Data)
    case send(AppFeature.Action)
}

extension AgentContract {
    /// Each screen's actions with their argument types, as `ls` lists them (contract.json; the
    /// check-driver-contract guard keeps the names in step).
    public static let schema: [String: [String: [String: String]]] = [
        "setup": [
            "nameChanged": ["kid": "int", "text": "string"], "ageChanged": ["kid": "int", "text": "string"],
            "faceTapped": ["kid": "int", "face": "string"], "addKidTapped": [:], "removeKidTapped": ["kid": "int"],
            "removeConfirmed": [:], "removeCancelled": [:], "nextTapped": [:], "schoolTextChanged": ["text": "string"],
            "schoolPicked": ["school": "string"], "wayPicked": ["way": "walk|bus|car|taxi|shuttle"],
            "stopTextChanged": ["text": "string"], "busTapped": ["bus": "string"], "walkChanged": ["minutes": "int"],
        ],
        "home": ["clockHeld": [:], "missionsTapped": [:]],
        "lock": ["primaryTapped": [:], "cancelTapped": [:]],
        "ourDay": ["settingsTapped": [:], "backTapped": [:]],
        "settings": ["addChildTapped": [:], "backTapped": [:]],
        "addChild": [
            "nameChanged": ["text": "string"], "ageChanged": ["text": "string"], "faceTapped": ["face": "string"],
            "saveTapped": [:], "backTapped": [:],
        ],
    ]

    /// One driver request: `GET /ls`, or `POST /do` with `{"action": "<screen>.<action>", "args": {…}}`.
    public static func reply(method: String, path: String, body: Data, state: AppFeature.State) -> AgentReply {
        switch (method, path) {
        case ("GET", "/ls"):
            return .answer(status: 200, json: lsJSON(state))
        case ("POST", "/do"):
            guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let name = object["action"] as? String else {
                return refused(#"send {"action": "<screen>.<action>", "args": {}}"#)
            }
            let args = (object["args"] as? [String: Any] ?? [:]).mapValues(AgentValue.init(json:))
            switch action(name, args, in: state) {
            case let .success(sent): return .send(sent)
            case let .failure(refusal): return refused(refusal.reason)
            }
        default:
            return .answer(status: 404, json: encode(["error": "use GET /ls or POST /do"]))
        }
    }

    /// `ls` as the driver sends it.
    public static func lsJSON(_ state: AppFeature.State) -> Data {
        let shown = ls(state)
        let actions = (schema[shown.screen] ?? [:]).keys.sorted().map { name -> [String: Any] in
            ["name": "\(shown.screen).\(name)", "args": schema[shown.screen]?[name] ?? [:]]
        }
        return encode([
            "screen": shown.screen, "stack": shown.stack, "fields": shown.fields.mapValues(\.json),
            "app": shown.app.mapValues(\.json), "actions": actions,
        ])
    }

    private static func refused(_ reason: String) -> AgentReply {
        .answer(status: 400, json: encode(["error": reason]))
    }

    private static func encode(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
    }
}
