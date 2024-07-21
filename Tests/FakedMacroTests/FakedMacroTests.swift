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
        @Faked(types: ["X": Int.self, "Y": String.self]) protocol Thing {
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
        @Faked(types: ["Missing": Int.self])
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
}
