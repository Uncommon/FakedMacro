import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(FakedMacroMacros)
@testable
import FakedMacroMacros

let testMacros: [String: Macro.Type] = [
    "Faked": FakedMacro.self,
    "Faked_Imp": FakedImpMacro.self,
    "FakeDefault": FakeDefaultMacro.self,
]
#endif

final class FakedMacroTests: XCTestCase
{
  func testMacro() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked protocol Thing {
          var x: Int { get }
          func perform()
        }
        """,
        expandedSource: """
        protocol Thing {
          var x: Int { get }
          func perform()
        }
        
        protocol EmptyThing: Thing {
          var x: Int { get }
          func perform()
        }
        
        struct NullThing: EmptyThing {}
        
        extension EmptyThing {
          var x: Int { 0 }
          func perform() {}
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testCollections() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked protocol Thing {
          var x: [Int] { get }
          var y: [String: Int] { get }
          func arrayfunc() -> [Int] { get }
          func dictFunc() -> [String: Int]
        }
        """,
        expandedSource: """
        protocol Thing {
          var x: [Int] { get }
          var y: [String: Int] { get }
          func arrayfunc() -> [Int] { get }
          func dictFunc() -> [String: Int]
        }
        
        protocol EmptyThing: Thing {
          var x: [Int] { get }
          var y: [String: Int] { get }
          func arrayfunc() -> [Int] { get }
          func dictFunc() -> [String: Int]
        }
        
        struct NullThing: EmptyThing {}
        
        extension EmptyThing {
          var x: [Int] { [] }
          var y: [String: Int] { [:] }
          func arrayfunc() -> [Int]  { [] }
          func dictFunc() -> [String: Int] { [:] }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testOptionals() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked protocol Thing {
          var x: Int? { get }
          var y: (any Identifiable)? { get }
          func intFunc() -> Int?
          func idFunc() -> (any Identifiable)?
        }
        """,
        expandedSource: """
        protocol Thing {
          var x: Int? { get }
          var y: (any Identifiable)? { get }
          func intFunc() -> Int?
          func idFunc() -> (any Identifiable)?
        }
        
        protocol EmptyThing: Thing {
          var x: Int? { get }
          var y: (any Identifiable)? { get }
          func intFunc() -> Int?
          func idFunc() -> (any Identifiable)?
        }
        
        struct NullThing: EmptyThing {}
        
        extension EmptyThing {
          var x: Int? { nil }
          var y: (any Identifiable)? { nil }
          func intFunc() -> Int? { nil }
          func idFunc() -> (any Identifiable)? { nil }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testClass() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked protocol Thing: AnyObject {
          func intFunc() -> Int
        }
        """,
        expandedSource: """
        protocol Thing: AnyObject {
          func intFunc() -> Int
        }
        
        protocol EmptyThing: Thing {
          func intFunc() -> Int
        }
        
        class NullThing: EmptyThing {}
        
        extension EmptyThing {
          func intFunc() -> Int { 0 }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testAssociatedType() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked(types: ["X": "Int", "Y": "String"]) protocol Thing {
          associatedtype X
          associatedtype Y
          associatedtype Z
        
          var x: Int { get }
          func intFunc() -> Int
        }
        """,
        expandedSource: """
        protocol Thing {
          associatedtype X
          associatedtype Y
          associatedtype Z
        
          var x: Int { get }
          func intFunc() -> Int
        }
        
        protocol EmptyThing: Thing {
          var x: Int { get }
          func intFunc() -> Int
        }
        
        struct NullThing: EmptyThing {
          typealias X = Int
          typealias Y = String
          typealias Z = NullZ
        }
        
        extension EmptyThing {
          var x: Int { 0 }
          func intFunc() -> Int { 0 }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  /// Example from Xit
  func testWritingManagementCase() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked
        public protocol WritingManagement
        {
          /// True if the repository is currently performing a writing operation.
          var isWriting: Bool { get }

          /// Performs `block` with `isWriting` set to true. Throws an exception if
          /// `isWriting` is already true.
          func performWriting(_ block: (() throws -> Void)) throws
        }
        """,
        expandedSource: """
        public protocol WritingManagement
        {
          /// True if the repository is currently performing a writing operation.
          var isWriting: Bool { get }

          /// Performs `block` with `isWriting` set to true. Throws an exception if
          /// `isWriting` is already true.
          func performWriting(_ block: (() throws -> Void)) throws
        }

        protocol EmptyWritingManagement: WritingManagement {
          var isWriting: Bool { get }
          func performWriting(_ block: (() throws -> Void)) throws
        }
        
        struct NullWritingManagement: EmptyWritingManagement {}
        
        extension EmptyWritingManagement {
          var isWriting: Bool { false }
          func performWriting(_ block: (() throws -> Void)) throws {}
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testAssocTypeNotSpecified() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked
        public protocol Thing: AnyObject
        {
          associatedtype Sequence: Swift.Sequence
          func perform()
        }
        """,
        expandedSource: """
        public protocol Thing: AnyObject
        {
          associatedtype Sequence: Swift.Sequence
          func perform()
        }

        protocol EmptyThing: Thing {
          func perform()
        }
        
        class NullThing: EmptyThing {
          typealias Sequence = NullSequence
        }
        
        extension EmptyThing {
          func perform() {}
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  /// Warnings for types listed in `types` parameter that don't match
  /// the protocol's associated types.
  func testMismatchedType() throws
  {
    #if canImport(FakedMacroMacros)
    let mismatchWarning = FakedMacroMacros.FakedWarning.typeNotFound("Missing")
    
    assertMacroExpansion(
        """
        @Faked(types: ["Missing": "Int"])
        public protocol Thing: AnyObject
        {
          associatedtype Sequence: Swift.Sequence
          func perform()
        }
        """,
        expandedSource: """
        public protocol Thing: AnyObject
        {
          associatedtype Sequence: Swift.Sequence
          func perform()
        }

        protocol EmptyThing: Thing {
          func perform()
        }
        
        class NullThing: EmptyThing {
          typealias Sequence = NullSequence
        }
        
        extension EmptyThing {
          func perform() {}
        }
        """,
        diagnostics: [.init(message: mismatchWarning.message,
                            line: 1, column: 1, severity: .warning)],
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testOtherCollections() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked
        public protocol Thing: AnyObject
        {
          func makeSet() -> Set<Int>
          func makeSequence() -> AnySequence<Int>
        }
        """,
        expandedSource: """
        public protocol Thing: AnyObject
        {
          func makeSet() -> Set<Int>
          func makeSequence() -> AnySequence<Int>
        }

        protocol EmptyThing: Thing {
          func makeSet() -> Set<Int>
          func makeSequence() -> AnySequence<Int>
        }
        
        class NullThing: EmptyThing {}
        
        extension EmptyThing {
          func makeSet() -> Set<Int> { [] }
          func makeSequence() -> AnySequence<Int> { .init(Array<Int>()) }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testDefaultMacro() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked
        public protocol Thing: AnyObject
        {
          @FakeDefault(1) var x: Int
          @FakeDefault(true) func determine() -> Bool
        }
        """,
        expandedSource: """
        public protocol Thing: AnyObject
        {
          var x: Int
          func determine() -> Bool
        }

        protocol EmptyThing: Thing {
          var x: Int
          func determine() -> Bool
        }
        
        class NullThing: EmptyThing {}
        
        extension EmptyThing {
          var x: Int { 1 }
          func determine() -> Bool { true }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testDefaultMacroExp() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked
        public protocol Thing: AnyObject
        {
          @FakeDefault(exp: "x") func determine(x: Int) -> Int
        }
        """,
        expandedSource: """
        public protocol Thing: AnyObject
        {
          func determine(x: Int) -> Int
        }

        protocol EmptyThing: Thing {
          func determine(x: Int) -> Int
        }
        
        class NullThing: EmptyThing {}
        
        extension EmptyThing {
          func determine(x: Int) -> Int { x }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testDefaultWrongType() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @FakeDefault(0)
        struct Wrong {}
        """,
        expandedSource: """
        struct Wrong {}
        """,
        diagnostics: [.init(message: FakedError.defaultVarFunc.message,
                            line: 1, column: 1)],
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testVariousDefaults() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked
        public protocol Thing: AnyObject
        {
          @FakeDefault(1) var x: Int
          var y: String
          var z: Unknown
          @FakeDefault(1) func a() -> Int
          func b() -> String
          func z() -> Unknown
        }
        """,
        expandedSource: """
        public protocol Thing: AnyObject
        {
          var x: Int
          var y: String
          var z: Unknown
          func a() -> Int
          func b() -> String
          func z() -> Unknown
        }

        protocol EmptyThing: Thing {
          var x: Int
          var y: String
          var z: Unknown
          func a() -> Int
          func b() -> String
          func z() -> Unknown
        }
        
        class NullThing: EmptyThing {}
        
        extension EmptyThing {
          var x: Int { 1 }
          var y: String { "" }
          var z: Unknown { .fakeDefault() }
          func a() -> Int { 1 }
          func b() -> String { "" }
          func z() -> Unknown { .fakeDefault() }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
  
  func testAnyObjectOverride() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked(anyObject: true) protocol Thing: Other {
          func intFunc() -> Int
        }
        """,
        expandedSource: """
        protocol Thing: Other {
          func intFunc() -> Int
        }
        
        protocol EmptyThing: Thing {
          func intFunc() -> Int
        }
        
        class NullThing: EmptyThing {}
        
        extension EmptyThing {
          func intFunc() -> Int { 0 }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testInheritance() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked(inherit: ["EmptyOne", "EmptyTwo"]) protocol Thing {
          func intFunc() -> Int
        }
        """,
        expandedSource: """
        protocol Thing {
          func intFunc() -> Int
        }
        
        protocol EmptyThing: Thing, EmptyOne, EmptyTwo {
          func intFunc() -> Int
        }
        
        struct NullThing: EmptyThing {}
        
        extension EmptyThing {
          func intFunc() -> Int { 0 }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testGetSet() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked protocol Thing {
          var x: Int { get set }
        }
        """,
        expandedSource: """
        protocol Thing {
          var x: Int { get set }
        }
        
        protocol EmptyThing: Thing {
          var x: Int { get set }
        }
        
        struct NullThing: EmptyThing {}
        
        extension EmptyThing {
          var x: Int { get { 0 } set {} }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testSkip() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked(skip: ["prop1", "func2"]) protocol Thing {
          var prop1: Int { get }
          var prop2: Int { get }
          func func1() -> Int
          func func2() -> Int
        }
        """,
        expandedSource: """
        protocol Thing {
          var prop1: Int { get }
          var prop2: Int { get }
          func func1() -> Int
          func func2() -> Int
        }
        
        protocol EmptyThing: Thing {
          var prop2: Int { get }
          func func1() -> Int
        }
        
        struct NullThing: EmptyThing {}
        
        extension EmptyThing {
          var prop2: Int { 0 }
          func func1() -> Int { 0 }
        }
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testSkipNull() throws
  {
    #if canImport(FakedMacroMacros)
    assertMacroExpansion(
        """
        @Faked(createNull: false) protocol Thing {
          var x: Int { get }
          func perform()
        }
        """,
        expandedSource: """
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
        """,
        macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
}
