#if DEBUG
import Domain
import Foundation

extension SetupFeature.State {
    /// Debug links `familyplanner://s1` … `s4`: setup at that step, S2–S4 filled with the sample
    /// family (made-up values) so each board can be checked on the iPad. Nothing is saved unless
    /// Start is tapped.
    public static func sample(step: Int, calendar: Calendar) -> Self {
        var state = Self(firstKid: SeedData.kidA.id, calendar: calendar)
        guard step > 1 else { return state }
        var kidA = KidEntry(id: SeedData.kidA.id, colorIndex: 0)
        kidA.name = SeedData.kidA.name
        kidA.ageText = "\(SeedData.kidA.age)"
        kidA.face = SeedData.kidA.face
        if let school = SeedData.kidA.school {
            kidA.school.text = school.name
            kidA.school.typedByHand = true
            kidA.school.start = school.start
            kidA.school.end = school.end
            kidA.school.arriveBy = school.start
            kidA.school.latest = school.start + 10
        }
        var kidB = KidEntry(id: SeedData.kidB.id, colorIndex: 1)
        kidB.name = SeedData.kidB.name
        kidB.ageText = "\(SeedData.kidB.age)"
        kidB.face = SeedData.kidB.face
        kidB.goesToChoice = .home
        state.kids = [kidA, kidB]
        state.step = switch step {
        case 2: .school
        case 3: .gettingThere(0)
        default: .almostDone
        }
        return state
    }
}
#endif
