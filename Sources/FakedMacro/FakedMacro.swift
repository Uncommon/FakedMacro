/// When attached to a protocol, creates a child protocol with default
/// implementations for all members - returning `nil`, `0`, or other empty
/// values.
@attached(peer, names: prefixed(Empty), prefixed(Null))
public macro Faked(types: [String: Any.Type] = [:]) = #externalMacro(
    module: "FakedMacroMacros",
    type: "FakedMacro")

/// Used by `@Faked` to produce the actual implementations, since an
/// extension must specifically be added by an extension macro.
@attached(extension, names: arbitrary)
public macro Faked_Imp() = #externalMacro(
    module: "FakedMacroMacros",
    type: "FakedImpMacro")

/// Specifies a default value to be returned by an "Empty" property or
/// function implementation.
@attached(peer)
public macro FadeDefault<T>(_ value: T) = #externalMacro(
    module: "FakedMacroMacros",
    type: "FakeDefaultMacro")
