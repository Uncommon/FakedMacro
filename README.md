# `@Faked` Macro

The `@Faked` macro makes it more convenient to create implementations of your protocols for tests and previews.

When attached to a protocol, this macro creates a child protocol prefixed with `Empty` that has implementations of all properties and functions returning default values, such as zero, `nil`, or empty arrays. It also creates a concrete type prefixed with `Null` - either a `struct` or a `class` depedning on whether the original protocol inherits from `AnyObject` - which inherits from the `Empty` protocol.

For your tests and previews, you can inherit from the `Empty` protocol so that you only have to implement the members needed for that context, and the rest are covered by the "empty" implementations.

For example, this:

```swift
@Faked protocol Thing {
    var x: Int { get }
    func perform()
}
```
expands to this:
```swift
protocol Thing {
    var x: Int { get }
    func perform()
}
protocol EmptyThing: Thing {
    var x: Int { get }
    func perform()
}
extension EmptyThing {
    var x: Int { 0 }
    func perform() {}
}
struct NullThing: EmptyThing {}
```

Then in some test where only the `perform()` function matters, you can create this test-specific struct:

```swift
struct FakeThing: EmptyThing {
    func perform() {
        // some fake implementation
    }
}
```

### Associated types

If the protocol has associated types, you can to specify which concrete types to use in the "Null" type. By default, a "Null" prefix will be added. This is done with the `types` parameter:

```swift
@Faked(types: ["X": Int.self, "Y": String.self])
protocol Thing {
    associatedtype X
    associatedtype Y
    associatedType Z
    func intFunc() -> Int
}
```

The resulting concrete type will be:

```swift
struct NullThing: EmptyThing {
    typealias X = Int
    typealias Y = String
    typealias Z = NullZ  // not specified, defaults to "Null" prefix
}
```

### Implementation note

Notice than in the example above, `EmptyThing` duplicates all the members from `Thing`. This is because of an implementation detail: `@Faked` is a two-stage macro. `@Faked` itself is a "peer macro", creating `EmptyThing` and `NullThing` as _peers_ of the original protocol. It also attaches a second macro, `@Thing_Imp`, to `EmptyThing`. `@Thing_Imp` is an "extension macro", and only extension macros may create extensions (and only of the protocol they're attached to), so it creates the extension with the default implementations. Since `@Thing_Imp` can't see anything outside the protocol it's attached to, all the members of `Thing` must be duplicated in `EmptyThing` so the second macro can see them.

Unfortunately, as of Xcode 15.4 (and 16 beta), expanding a nested macro doesn't work.
