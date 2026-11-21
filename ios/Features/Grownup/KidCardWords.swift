import DesignSystem
import KitArt
import Strings

extension KidCard.Words {
    /// The kid card's words (S1 and G6f "Add a child", spec "Kid card"), read through `strings`.
    public static func kid(_ strings: Localizer) -> Self {
        Self(name: strings.tr("s1.name"), namePlaceholder: strings.tr("s1.name.placeholder"),
             age: strings.tr("s1.age"), agePlaceholder: strings.tr("s1.age.placeholder"),
             colour: strings.tr("s1.colour"), face: strings.tr("s1.face"),
             colourCount: 4, faces: [.kidGirl, .kidBoy])
    }
}
