import Strings

/// Words the shared grown-up parts show on every screen: the header's caption and Back button, and
/// the time wheel's name. A screen State conforms by keeping `strings` (`Localizer.injected`).
public protocol GrownupWords {
    var strings: Localizer { get }
}

extension GrownupWords {
    /// The header's right side when the screen has no control there (board 0f).
    public var headerCaption: String { strings.tr("grownup.caption") }
    /// The header's Back button, for VoiceOver.
    public var backLabel: String { strings.tr("grownup.back") }
    /// A time field's wheel, for VoiceOver.
    public var timePickerTitle: String { strings.tr("time.field") }
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
