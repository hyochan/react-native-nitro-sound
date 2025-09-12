// Suppress console logs in production (Release) builds only for this module
#if !DEBUG
@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
#endif

