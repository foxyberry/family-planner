import Strings

/// Words the shared grown-up parts show on every screen: the header's caption. A screen State
/// conforms by keeping `strings` (`Localizer.injected`).
public protocol GrownupWords {
    var strings: Localizer { get }
}

extension GrownupWords {
    /// The header's right side when the screen has no control there (board 0f).
    public var headerCaption: String { strings.tr("grownup.caption") }
}

extension AddChildFeature.State: GrownupWords {}
extension BusSettingsFeature.State: GrownupWords {}
extension ChangeBusesFeature.State: GrownupWords {}
extension ChangeSchoolFeature.State: GrownupWords {}
extension ChangeSchoolFeature.Form: GrownupWords {}
extension DataSourcesFeature.State: GrownupWords {}
extension ItemEditorFeature.State: GrownupWords {}
extension MissionEditorFeature.State: GrownupWords {}
extension OurDayFeature.State: GrownupWords {}
extension SchoolEditorFeature.State: GrownupWords {}
extension SettingsFeature.State: GrownupWords {}
