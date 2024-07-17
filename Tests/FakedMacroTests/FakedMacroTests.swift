import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(FakedMacroMacros)
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
        
        protocol EmptyThing : Thing {
          var x: Int { get }
          func perform()
        }
        
        struct NullThing : EmptyThing {}
        
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
        
        protocol EmptyThing : Thing {
          var x: [Int] { get }
          var y: [String: Int] { get }
          func arrayfunc() -> [Int] { get }
          func dictFunc() -> [String: Int]
        }
        
        struct NullThing : EmptyThing {}
        
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
      func intfunc() -> Int?
      func idFunc() -> (any Identifiable)?
    }
    """,
    expandedSource: """
    protocol Thing {
      var x: Int? { get }
      var y: (any Identifiable)? { get }
      func intfunc() -> Int?
      func idFunc() -> (any Identifiable)?
    }
    
    protocol EmptyThing : Thing {
      var x: Int? { get }
      var y: (any Identifiable)? { get }
      func intfunc() -> Int?
      func idFunc() -> (any Identifiable)?
    }
    
    struct NullThing : EmptyThing {}
    
    extension EmptyThing {
      var x: Int? { nil }
      var y: (any Identifiable)? { nil }
      func intfunc() -> Int? { nil }
      func idFunc() -> (any Identifiable)? { nil }
    }
    """,
    macros: testMacros
)
#else
throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
  }
}
