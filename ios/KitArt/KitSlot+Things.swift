public extension KitSlot {
    /// A thing a kid can bring (Bring's "More", spec "Event form rows"): objects only, never a
    /// place, an activity, a person, a vehicle, a reward, a feeling or a UI picture. Every case is
    /// listed, so a new picture does not build until someone decides.
    var isThing: Bool {
        switch self {
        case .toothbrush, .hairBrush, .shirt, .backpack, .lunchBox, .waterBottle, .shoe, .homework, .blocks,
             .snack, .pyjamas, .teddy, .milk, .babyBottle, .cake:
            true
        case .sun, .toilet, .washFace, .actBreakfast, .actSchool, .wolfie, .actPlay, .playground, .actDinner, .tv,
             .actCCA, .actArt, .actMusic, .actPiano, .actDance, .actFootball, .actSwim, .actStory,
             .actLanguageSchool, .actChurch, .flagKR, .flagJP, .flagCN, .flagUK, .flagFR, .flagIN, .flagTH, .flagVN,
             .actShower, .actSleep, .kidGirl, .kidBoy, .busMini, .busSingle, .busDouble, .busShuttle, .car, .taxi,
             .busSinglePax1, .busSinglePax2, .busSinglePax3, .busDoublePax1, .busDoublePax2, .busDoublePax3,
             .busMiniPax1, .busMiniPax2, .busMiniPax3, .medalGold, .medalSilver, .medalBronze, .star, .crown,
             .doctor, .home, .feelVeryHappy, .feelHappy, .feelOK, .feelSad, .feelVerySad, .energyLots,
             .energyGood, .energyTired, .energyNone, .skyDay, .skyDusk, .skyNight, .pencil, .debugLadybug:
            false
        }
    }
}
