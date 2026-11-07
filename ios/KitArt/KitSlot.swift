/// Every place a crayon picture appears. The raw value is the asset name in KitArt.xcassets.
/// Keep this list equal to the generated catalog (scripts/tests/kitart-catalog-test.sh checks it).
public enum KitSlot: String, CaseIterable, Sendable {
    // Morning
    case sun, toilet, toothbrush, washFace, hairBrush, shirt, actBreakfast, backpack, lunchBox, waterBottle, shoe
    // School and play
    case actSchool, homework, actPlay, blocks, playground, snack, actDinner, tv
    // After-school activities
    case actCCA, actArt, actMusic, actPiano, actDance, actFootball, actSwim, actStory
    // Evening
    case actShower, pyjamas, teddy, actSleep
    // Children
    case kidGirl, kidBoy, milk, babyBottle
    // Getting there
    case busMini, busSingle, busDouble, car, taxi
    // Rewards and events
    case medalGold, medalSilver, medalBronze, star, cake, doctor, home
    // Feelings and energy
    case feelVeryHappy, feelHappy, feelOK, feelSad, feelVerySad
    case energyLots, energyGood, energyTired, energyNone
    // Developer tools (debug builds)
    case debugLadybug
}
