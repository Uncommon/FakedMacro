import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct FakedMacro: PeerMacro
{
  static public var formatMode: FormatMode { .disabled }
  
  public static func expansion(
      of node: SwiftSyntax.AttributeSyntax,
      providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
      in context: some SwiftSyntaxMacros.MacroExpansionContext) throws
    -> [SwiftSyntax.DeclSyntax]
  {
    guard let protocolDec = declaration.as(ProtocolDeclSyntax.self)
    else { throw FakedError.notAProtocol }
    let protocolName = protocolDec.name.text
    let emptyProtocolName = "Empty\(protocolName)"
    /// Includes newline at start
    let indent = Trivia(pieces: protocolDec.memberBlock.members.first?
      .decl.leadingTrivia.prefix { $0.isWhitespace } ?? [])
    let assocs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(AssociatedTypeDeclSyntax.self) }
    var concreteAssocTypes: [(String, String)] = []

    if case let .argumentList(arguments) = node.arguments,
       let types = arguments.first,
       let dict = types.expression.as(DictionaryExprSyntax.self),
       case let .elements(elements) = dict.content
    {
      for element in elements {
        guard let substitute = element.key.as(StringLiteralExprSyntax.self),
              let substituteName = substitute.representedLiteralValue,
              let type = element.value.as(MemberAccessExprSyntax.self),
              let typeName = type.base?.as(DeclReferenceExprSyntax.self)
        else {
          context.diagnose(.init(node: element,
                                 message: FakedError.wrongTypeSpecifier))
          return []
        }
        
        concreteAssocTypes.append((substituteName,
                                   typeName.baseName.text))
      }
    }

    if assocs.isEmpty {
      guard concreteAssocTypes.isEmpty
      else {
        context.diagnose(.init(node: node, message: FakedError.typesMissing))
        return []
      }
    }
    else {
      guard concreteAssocTypes.count == assocs.count
      else {
        context.diagnose(.init(node: node, message: FakedError.typesMismatch))
        return []
      }
    }

    let emptyProtocol = try createEmptyProtocol(
        protocolDec: protocolDec,
        indent: indent,
        emptyProtocolName: emptyProtocolName)
    let nullType = try createNullType(
        protocolDec: protocolDec,
        indent: indent,
        concreteAssocTypes: concreteAssocTypes,
        emptyProtocolName: emptyProtocolName)

    return [DeclSyntax(emptyProtocol),
            DeclSyntax(nullType)]
  }
  
  static func createEmptyProtocol(
      protocolDec: ProtocolDeclSyntax,
      indent: Trivia,
      emptyProtocolName: String) throws -> ProtocolDeclSyntax
  {
    let protocolName = protocolDec.name.text
    let vars = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(VariableDeclSyntax.self)?.withIndent(indent) }
    let funcs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(FunctionDeclSyntax.self)?.withIndent(indent) }
    var emptyProtocol = try ProtocolDeclSyntax(
        """
        protocol \(raw: emptyProtocolName): \(raw: protocolName) {
        }
        """)
    
    emptyProtocol.attributes.append(.attribute(
        .init(stringLiteral: "@Faked_Imp ")))
    
    // Copy in the properties and functions
    emptyProtocol.memberBlock.members = .init {
      for property in vars { property }
      for function in funcs { function }
    }
    
    return emptyProtocol
  }
  
  static func createNullType(
      protocolDec: ProtocolDeclSyntax,
      indent: Trivia,
      concreteAssocTypes: [(String, String)],
      emptyProtocolName: String) throws -> any DeclSyntaxProtocol
  {
    let protocolName = protocolDec.name.text
    let indentSpace = Trivia(pieces: indent.filter { $0.isSpaceOrTab })
    let isAnyObject = protocolDec.inheritanceClause?.inheritedTypes.contains {
      if let identifier = $0.type.as(IdentifierTypeSyntax.self),
         identifier.name.text == "AnyObject" {
        return true
      }
      else {
        return false
      }
    } ?? false
    let nullIdentifier: TokenSyntax = .identifier("Null\(protocolName)")
                                      .withLeadingSpace
    let inheritance = InheritanceClauseSyntax(
      colon: .colonToken(trailingTrivia: .space)) {
      InheritedTypeSyntax(type: TypeSyntax(stringLiteral: emptyProtocolName),
                          trailingTrivia: .space)
    }
    let braceTrivia: Trivia = concreteAssocTypes.isEmpty ? [] : .newline
    var nullMemberBlock = MemberBlockSyntax(
        leftBrace: .leftBraceToken(trailingTrivia: braceTrivia),
        members: [])
    
    for type in concreteAssocTypes {
      let member = MemberBlockItemSyntax(
        leadingTrivia: indentSpace,
          decl: try TypeAliasDeclSyntax("typealias \(raw: type.0) = \(raw: type.1)"),
          trailingTrivia: .newline)
      
      nullMemberBlock.members.append(member)
    }

    return isAnyObject
        ? ClassDeclSyntax(name: nullIdentifier,
                          inheritanceClause: inheritance,
                          memberBlock: nullMemberBlock)
        : StructDeclSyntax(name: nullIdentifier,
                           inheritanceClause: inheritance,
                           memberBlock: nullMemberBlock)
  }
}

@main
struct FakedMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    FakedMacro.self,
    FakedImpMacro.self,
  ]
}
