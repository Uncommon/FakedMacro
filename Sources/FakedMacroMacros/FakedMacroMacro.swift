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
    let indentWithNewline = Trivia(pieces:
        protocolDec.memberBlock.members.first?
        .decl.leadingTrivia.prefix { $0.isWhitespace } ?? [])
    var concreteAssocTypes: [String: String] = [:]
    var inheritedTypes: [String] = []

    if case let .argumentList(arguments) = node.arguments {
      if let types = arguments.first(where:
         { $0.label?.trimmedDescription == "types" }),
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
          
          concreteAssocTypes[substituteName] = typeName.baseName.text
        }
      }
      if let inherit = arguments.first(where:
          { $0.label?.trimmedDescription == "inherit" }),
         let types = inherit.expression.as(ArrayExprSyntax.self) {
        // Ideally these types would be passed as SomeType.self rather than
        // raw strings, but if that type is introduced by another macro, then
        // it doesn't exist when this macro is being expanded.
        inheritedTypes = types.elements.compactMap {
          $0.expression.as(StringLiteralExprSyntax.self)?
            .representedLiteralValue
        }
      }
    }

    let emptyProtocol = try createEmptyProtocol(
        protocolDec: protocolDec,
        indent: indentWithNewline,
        inheritedTypes: inheritedTypes,
        emptyProtocolName: emptyProtocolName)
    let nullType = try createNullType(
        in: context,
        node: node,
        protocolDec: protocolDec,
        indent: indentWithNewline,
        concreteAssocTypes: concreteAssocTypes,
        emptyProtocolName: emptyProtocolName)

    return [DeclSyntax(emptyProtocol),
            DeclSyntax(nullType)]
  }
  
  static func createEmptyProtocol(
      protocolDec: ProtocolDeclSyntax,
      indent: Trivia,
      inheritedTypes: [String],
      emptyProtocolName: String) throws -> ProtocolDeclSyntax
  {
    let protocolName = protocolDec.name.text
    let vars = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(VariableDeclSyntax.self)?.withIndent(indent) }
    let funcs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(FunctionDeclSyntax.self)?.withIndent(indent) }
    let inherits = inheritedTypes.map { ", " + $0 }.joined()
    var emptyProtocol = try ProtocolDeclSyntax(
        """
        protocol \(raw: emptyProtocolName): \(raw: protocolName)\(raw: inherits) {
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
      in context: some SwiftSyntaxMacros.MacroExpansionContext,
      node: SwiftSyntax.AttributeSyntax,
      protocolDec: ProtocolDeclSyntax,
      indent: Trivia,
      concreteAssocTypes: [String: String],
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
    let anyObjectOverride = {
      if case let .argumentList(arguments) = node.arguments,
         let anyObject = arguments.first(where: { $0.label?.trimmedDescription == "anyObject"}),
         let expr = anyObject.expression.as(BooleanLiteralExprSyntax.self),
         expr.literal.trimmedDescription == "true" {
        true
      }
      else {
        false
      }
    }()
    let nullIdentifier: TokenSyntax = .identifier("Null\(protocolName)")
                                      .withLeadingSpace
    let inheritance = InheritanceClauseSyntax(
      colon: .colonToken(trailingTrivia: .space)) {
      InheritedTypeSyntax(type: TypeSyntax(stringLiteral: emptyProtocolName),
                          trailingTrivia: .space)
    }
    let assocs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(AssociatedTypeDeclSyntax.self) }
    let braceTrivia: Trivia = assocs.isEmpty ? [] : .newline
    var nullMemberBlock = MemberBlockSyntax(
        leftBrace: .leftBraceToken(trailingTrivia: braceTrivia),
        members: [])
    let associatedNames = assocs.map { $0.name.text }

    for mismatchedKey in concreteAssocTypes.keys.filter({
      !associatedNames.contains($0)
    }) {
      context.diagnose(
        .init(node: node,
              message: FakedWarning.typeNotFound(mismatchedKey)))
    }
    
    for type in assocs {
      let name = type.name.text
      let alias = concreteAssocTypes[name] ?? "Null" + name
      let member = MemberBlockItemSyntax(
          leadingTrivia: indentSpace,
            decl: try TypeAliasDeclSyntax(
                "typealias \(raw: name) = \(raw: alias)"),
            trailingTrivia: .newline)

      nullMemberBlock.members.append(member)
    }

    return isAnyObject || anyObjectOverride
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
