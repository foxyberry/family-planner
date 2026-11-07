/// Deterministic random numbers using the same Park–Miller LCG as Rough.js (`random.ts`):
/// `seed = imul(48271, seed)`, value = `(2^31 - 1 & seed) / 2^31`. Same seed, same shape, every time.
public struct SeededRandom: Sendable {
    private var state: Int32

    public init(seed: UInt32) {
        // Rough.js falls back to Math.random() for seed 0; stay deterministic instead.
        state = Int32(bitPattern: seed == 0 ? 1 : seed)
    }

    /// A value in [0, 1).
    public mutating func next() -> Double {
        state = 48271 &* state
        return Double(state & 0x7FFF_FFFF) / 2_147_483_648
    }

    /// A value in [-1, 1).
    mutating func signed() -> Double { next() * 2 - 1 }
}
