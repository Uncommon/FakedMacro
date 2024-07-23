import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

public struct FakeDefaultMacro: PeerMacro
{
  public static func expansion(
      of node: SwiftSyntax.AttributeSyntax,
      providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
      in context: some SwiftSyntaxMacros.MacroExpansionContext) throws
    -> [SwiftSyntax.DeclSyntax]
  {
    // This macro does nothing by itself. It only exists to be examined by
    // FakedImpMacro. Ideally it should be an error to use it outside a
    // protocol with @Faked on it, but that's not currently possible.
    if !declaration.is(VariableDeclSyntax.self) &&
        !declaration.is(FunctionDeclSyntax.self) {
      context.diagnose(.init(node: node,
                             message: FakedError.defaultVarFunc))
    }
    return []
  }
}
