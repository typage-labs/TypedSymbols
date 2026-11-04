import TypedSymbols
// `asterisk.circle` is old, but `asterisk` itself needs iOS 15 / macOS 12.
// The documented conservative path policy must reject this at the baseline.
let invalid = Symbol.asterisk.circle
