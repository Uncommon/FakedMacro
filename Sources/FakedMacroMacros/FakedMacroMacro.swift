import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum FakedError: Swift.Error, DiagnosticMessage
{
  case bindingCount
  case notAProtocol
  case invalidMember
  case typesMissing
  case typesMismatch
  case unhandledType
  case wrongTypeSpecifier

  var message: String
  {
    switch self {
      case .bindingCount:
        "Each `var` must have exactly one binding"
      case .notAProtocol:
        "Macro must be attached to a protocol"
      case .invalidMember:
        "Unsupported protocol member found"
      case .typesMissing:
        "Types not specified for protocol with associated types"
      case .typesMismatch:
        "Types count does not match associated types count"
      case .unhandledType:
        "Result type not supported"
      case .wrongTypeSpecifier:
        "Types must be specified as a string literal and a type such as `Int.self`"
    }
  }
  
  var diagnosticID: MessageID { .init(domain: "FakedMacro", id: "\(self)") }
  
  var severity: DiagnosticSeverity { .error }
}

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
    var emptyProtocol = try SwiftSyntax.ProtocolDeclSyntax(
        """
        protocol \(raw: emptyProtocolName): \(raw: protocolName) {
        }
        """)
    /// Includes newline at start
    let indent = Trivia(pieces: protocolDec.memberBlock.members.first?
      .decl.leadingTrivia.prefix { $0.isWhitespace } ?? [])
    let indentSpace = Trivia(pieces: indent.filter { $0.isSpaceOrTab })
    let vars = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(VariableDeclSyntax.self)?.withIndent(indent) }
    let funcs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(FunctionDeclSyntax.self)?.withIndent(indent) }
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
    
    emptyProtocol.attributes.append(.attribute(
        .init(stringLiteral: "@Faked_Imp ")))
    
    // Copy in the properties and functions
    emptyProtocol.memberBlock.members = .init {
      for property in vars { property }
      for function in funcs { function }
    }
    
    let isAnyObject = protocolDec.inheritanceClause?.inheritedTypes.contains {
      if let identifier = $0.type.as(IdentifierTypeSyntax.self),
         identifier.name.text == "AnyObject" {
        return true
      }
      else {
        return false
      }
    } ?? false
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
    
    let nullIdentifier: TokenSyntax = .identifier("Null\(protocolName)")
                                      .withLeadingSpace
    let inheritance = InheritanceClauseSyntax(
      colon: .colonToken(trailingTrivia: .space)) {
      InheritedTypeSyntax(type: TypeSyntax(stringLiteral: emptyProtocolName),
                          trailingTrivia: .space)
    }
    let nullType: any DeclSyntaxProtocol = isAnyObject
        ? ClassDeclSyntax(name: nullIdentifier,
                          inheritanceClause: inheritance,
                          memberBlock: nullMemberBlock)
        : StructDeclSyntax(name: nullIdentifier,
                           inheritanceClause: inheritance,
                           memberBlock: nullMemberBlock)
    
    return [DeclSyntax(emptyProtocol),
            DeclSyntax(nullType)]
  }
}

public struct FakedImpMacro: ExtensionMacro
{
  static public var formatMode: FormatMode { .disabled }
  
  public static func expansion(
      of node: AttributeSyntax,
      attachedTo declaration: some DeclGroupSyntax,
      providingExtensionsOf type: some TypeSyntaxProtocol,
      conformingTo protocols: [TypeSyntax],
      in context: some MacroExpansionContext)
    throws -> [ExtensionDeclSyntax]
  {
    guard let protocolDec = declaration.as(ProtocolDeclSyntax.self)
    else { throw FakedError.notAProtocol }
    var firstVar = true

    let members = try protocolDec.memberBlock.members.map {
      member -> DeclSyntaxProtocol in
      if let property = member.decl.as(VariableDeclSyntax.self) {
        defer { firstVar = false }
        return try defaultPropertyImp(property, isFirst: firstVar)
      }
      else if let function = member.decl.as(FunctionDeclSyntax.self) {
        firstVar = true
        return try defaultFunctionImp(function)
      }
      throw FakedError.invalidMember
    }
    let memberBlock = MemberBlockSyntax(
        leftBrace: TokenSyntax(.leftBrace,
                               leadingTrivia: .space,
                               trailingTrivia: .newline,
                               presence: .present),
        rightBrace: TokenSyntax(.rightBrace,
                                presence: .present)) {
      for member in members { member.withTrailingNewline }
    }
    
    return [ExtensionDeclSyntax(
        extensionKeyword: .keyword(.extension, trailingTrivia: .space),
        extendedType: type,
        memberBlock: memberBlock)]
  }
  
  static func defaultPropertyImp(_ property: VariableDeclSyntax,
                                 isFirst: Bool) throws -> VariableDeclSyntax
  {
    guard let binding = property.bindings.first
    else { throw FakedError.bindingCount }
    let type = binding.typeAnnotation!.type.description
    let defaultValue: String
    
    if let type = binding.typeAnnotation?.type {
      if let typeIdentifier = type.as(IdentifierTypeSyntax.self) {
        guard let identifierDefault = defaultIdentifierValue(typeIdentifier)
        else { throw FakedError.unhandledType }
        
        defaultValue = identifierDefault
      }
      else if type.is(ArrayTypeSyntax.self) {
        defaultValue = "[]"
      }
      else if type.is(DictionaryTypeSyntax.self) {
        defaultValue = "[:]"
      }
      else if type.is(OptionalTypeSyntax.self) {
        defaultValue = "nil"
      }
      else {
        throw FakedError.unhandledType
      }
    }
    else {
      throw FakedError.unhandledType
    }
    
    var decl = try VariableDeclSyntax(
      """
        var \(binding.pattern.detached): \(raw: type){ \(raw: defaultValue) }
      """
      )
    let trivia = Trivia(pieces: 
        property.bindingSpecifier.leadingTrivia.pieces
        .filter { !$0.isNewline })
    
    decl.bindingSpecifier = .keyword(.var,
                                     leadingTrivia: trivia,
                                     trailingTrivia: .space)
    return decl
  }
  
  static func defaultFunctionImp(_ function: FunctionDeclSyntax) throws -> FunctionDeclSyntax
  {
    var defaultValue = ""
    
    if let clause = function.signature.returnClause {
      if let identifier = clause.type.as(IdentifierTypeSyntax.self) {
        defaultValue = defaultIdentifierValue(identifier) ?? ""
      }
      else if clause.type.is(ArrayTypeSyntax.self) {
        defaultValue = "[]"
      }
      else if clause.type.is(DictionaryTypeSyntax.self) {
        defaultValue = "[:]"
      }
      else if clause.type.is(OptionalTypeSyntax.self) {
        defaultValue = "nil"
      }
    }
    
    var copy = function
    
    copy.body = .init(leadingTrivia: .space,
                      statements: .init(
                        stringLiteral: defaultValue.isEmpty ? "" :
                          " \(defaultValue) "))
    
    copy.leadingTrivia =
        Trivia(pieces: copy.leadingTrivia.filter { !$0.isNewline })
    
    return copy
  }
  
  static func defaultIdentifierValue(_ identifier: IdentifierTypeSyntax) -> String?
  {
    switch identifier.name.text {
      case "Int", "UInt", "Float", "Double":
        "0"
      case "String":
        #""""#
      case "Bool":
        "false"
      default:
        nil
    }
  }
}

@main
struct FakedMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    FakedMacro.self,
    FakedImpMacro.self,
  ]
}
