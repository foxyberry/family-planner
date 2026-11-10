import Strings

/// One switch on S4 and on Settings' Family tab (spec "S4 · Almost done", "G6 · Settings").
public enum AppSetting: CaseIterable, Hashable, Sendable { case grownupLock, liveBusTimes, medals }

/// A switch row's words: the title, the caption (the "off" meaning where it matters) and whether it
/// warns, with its picture: the lock mark, or a kit picture (a `KitSlot` raw value).
public struct AppSettingRow: Equatable, Sendable {
    public enum Picture: Equatable, Sendable { case lock, kit(String) }

    public let setting: AppSetting
    public let title: String
    public let caption: String
    public let isWarning: Bool
    public let isOn: Bool
    public let picture: Picture
}

public extension AppSettings {
    /// The switch rows in board order. `lockNeedsFaceID`: the lock could not be turned on (no Face ID).
    func rows(lockNeedsFaceID: Bool = false) -> [AppSettingRow] {
        AppSetting.allCases.map { setting in
            switch setting {
            case .grownupLock:
                let caption = lockNeedsFaceID && !grownupLock ? L10n.tr("s4.lock.needs_face_id")
                    : grownupLock ? L10n.tr("s4.lock.caption") : L10n.tr("s4.lock.off")
                return AppSettingRow(setting: setting, title: L10n.tr("s4.lock"), caption: caption, isWarning: !grownupLock,
                                     isOn: grownupLock, picture: .lock)
            case .liveBusTimes:
                return AppSettingRow(setting: setting, title: L10n.tr("s4.live_bus"), caption: L10n.tr("s4.live_bus.caption"),
                                     isWarning: false, isOn: liveBusTimes, picture: .kit("busSingle")) // copy-ok: a KitSlot name
            case .medals:
                return AppSettingRow(setting: setting, title: L10n.tr("s4.medals"), caption: L10n.tr("s4.medals.caption"),
                                     isWarning: false, isOn: medals, picture: .kit("medalGold")) // copy-ok: a KitSlot name
            }
        }
    }
}
