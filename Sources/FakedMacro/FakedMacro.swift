/// When attached to a protocol, creates a child protocol prefixed with
/// "Empty", with default implementations for all members - returning `nil`,
/// `0`, or other empty values.
///
/// These default implementations make it easy to create partial
/// implementations of the protocol for tests and previews.
///
/// A concrete "Null"-prefixed type is also created, either a `class` or a
/// `struct` depending on whether the original protocol inherist from
/// `AnyObject`. To override this, pass `true` for the `anyObject` parameter,
/// such as when the protocol inherits `AnyObject` from a parent protocol.
/// This can be useful for when a concrete type is needed, but the values are
/// not important.
///
/// Associated types for the "Null" type also default to adding a "Null"
/// prefix, but can be overridden with the `types` parameter.
///
/// Default values are as follows:
/// * The `@FakeDefault` macro can specify a value for individual properties
/// and functions.
/// * Standard types will use `0`, `false`, `nil`, `[]`, etc.
/// * For unrecognized types, the `.fakeDefault()` static function will be
/// used, assuming that it exists.
///
/// - parameter types: Overrides for associated types. Key is protocol
/// associated type name, value is concrete type name.
/// - parameter anyObject: If `true`, the generated "Null" type will be a
/// `class`. Passing `false` has no effect.
/// - parameter inherit: Other types that the "Empty" protocol should
/// inherit. Specified as strings to allow for types introduced by other
/// macros.
@attached(peer, names: prefixed(Empty), prefixed(Null))
public macro Faked(types: [String: String] = [:],
                   anyObject: Bool = false,
                   inherit: [String] = []) = #externalMacro(
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
public macro FakeDefault<T>(_ value: T) = #externalMacro(
    module: "FakedMacroMacros",
    type: "FakeDefaultMacro")

/// It is not necessary to conform a type to `Fakable` as long as the
/// `fakeDefault()` function exists when needed.
protocol Fakable {
  /// Implement the `fakeDefault()` function for custom types that have a
  /// general purpose default value. The `@Faked` macro will fall back on this
  /// for types it does not recognize and where no specific default is
  /// specified with the `@FakeDefault` macro.
  static func fakeDefault() -> Self
}
