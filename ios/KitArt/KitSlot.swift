/// Every place a crayon picture appears. The raw value is the asset name in KitArt.xcassets.
/// Keep this list equal to the generated catalog (scripts/tests/kitart-catalog-test.sh checks it).
public enum KitSlot: String, CaseIterable, Sendable {
    // Morning
    case sun, toilet, toothbrush, washFace, hairBrush, shirt, actBreakfast, backpack, lunchBox, waterBottle, shoe
    // School and play
    case actSchool, wolfie, homework, actPlay, blocks, playground, snack, actDinner, tv
    // After-school activities
    case actCCA, actArt, actMusic, actPiano, actDance, actFootball, actSwim, actStory
    // Weekend
    case actLanguageSchool, actChurch
    // Flags (a weekend school's language; the plain flag is actLanguageSchool)
    case flagKR, flagJP, flagCN, flagUK, flagFR, flagIN, flagTH, flagVN
    // Evening
    case actShower, pyjamas, teddy, actSleep
    // Children
    case kidGirl, kidBoy, milk, babyBottle
    // Getting there
    case busMini, busSingle, busDouble, busShuttle, car, taxi
    // Bus windows with passengers, drawn over the bus (1 quiet … 3 crowded; N1)
    case busSinglePax1, busSinglePax2, busSinglePax3, busDoublePax1, busDoublePax2, busDoublePax3
    case busMiniPax1, busMiniPax2, busMiniPax3
    // Rewards and events
    case medalGold, medalSilver, medalBronze, star, crown, cake, doctor, home
    // Feelings and energy
    case feelVeryHappy, feelHappy, feelOK, feelSad, feelVerySad
    case energyLots, energyGood, energyTired, energyNone
    // Sky switch (day, mid-animation, night)
    case skyDay, skyDusk, skyNight
    // Grown-up mode way in (G0)
    case pencil
    // Developer tools (debug builds)
    case debugLadybug
}

public extension KitSlot {
    /// The picture saved under `iconName`, or the play picture when the name is unknown.
    init(iconName: String) {
        self = KitSlot(rawValue: iconName) ?? .actPlay
    }
}
