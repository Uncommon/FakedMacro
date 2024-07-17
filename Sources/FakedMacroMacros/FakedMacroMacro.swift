import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum Error: Swift.Error
{
  case notAProtocol
  case invalidMember
  case bindingCount
  case unhandledType
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
    else { throw Error.notAProtocol }
    let emptyProtocolName = "Empty\(protocolDec.name)"
    var emptyProtocol = try SwiftSyntax.ProtocolDeclSyntax(
        """
        protocol \(raw: emptyProtocolName): \(protocolDec.name){
        }
        """)
    let vars = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(VariableDeclSyntax.self) }
    let funcs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(FunctionDeclSyntax.self) }

    emptyProtocol.attributes.append(.attribute(
        .init(stringLiteral: "@Faked_Imp ")))
    
    // Copy in the properties and functions
    emptyProtocol.memberBlock.members = .init {
      for property in vars { property }
      for function in funcs { function }
    }
    
    let fakeStruct = try SwiftSyntax.StructDeclSyntax(
      """
        struct Null\(protocolDec.name): Empty\(protocolDec.name){}
      """
    )
    
    return [DeclSyntax(emptyProtocol),
            DeclSyntax(fakeStruct)]
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
    else { throw Error.notAProtocol }
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
      throw Error.invalidMember
    }
    let memberBlock = MemberBlockSyntax(
        leftBrace: TokenSyntax(.leftBrace,
                               leadingTrivia: .space,
                               trailingTrivia: .newline,
                               presence: .present),
        rightBrace: TokenSyntax(.rightBrace,
                                leadingTrivia: .newline,
                                presence: .present)) {
      for member in members { member }
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
    else { throw Error.bindingCount }
    let type = binding.typeAnnotation!.type.description
    let defaultValue: String
    
    if let typeIdentifier = binding.typeAnnotation!.type.as(IdentifierTypeSyntax.self) {
      guard let identifierDefault = defaultIdentifierValue(typeIdentifier)
      else { throw Error.unhandledType }
      
      defaultValue = identifierDefault
    }
    else if binding.typeAnnotation?.type.as(ArrayTypeSyntax.self) != nil {
      defaultValue = "[]"
    }
    else if binding.typeAnnotation?.type.as(DictionaryTypeSyntax.self) != nil {
      defaultValue = "[:]"
    }
    else if binding.typeAnnotation?.type.as(OptionalTypeSyntax.self) != nil {
      defaultValue = "nil"
    }
    else {
      throw Error.unhandledType
    }
    
    var decl = try VariableDeclSyntax(
      """
        var \(binding.pattern.detached): \(raw: type){ \(raw: defaultValue) }
      """
      )
    var trivia = property.bindingSpecifier.leadingTrivia
    
    if isFirst {
      trivia = Trivia(pieces: trivia.pieces.filter { !$0.isNewline })
    }
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
      else if clause.type.as(ArrayTypeSyntax.self) != nil {
        defaultValue = "[]"
      }
      else if clause.type.as(DictionaryTypeSyntax.self) != nil {
        defaultValue = "[:]"
      }
      else if clause.type.as(OptionalTypeSyntax.self) != nil {
        defaultValue = "nil"
      }
    }
    
    var copy = function
    
    copy.body = .init(leadingTrivia: .space,
                      statements: .init(
                        stringLiteral: defaultValue.isEmpty ? "" :
                          " \(defaultValue) "))
    return copy
  }
  
  static func defaultIdentifierValue(_ identifier: IdentifierTypeSyntax) -> String?
  {
    switch identifier.name.text {
      case "Int", "UInt", "Float", "Double":
        "0"
      case "String":
        #""""#
      default:
        nil
    }
  }
}

@main
struct FakedMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    FakedMacro.self,
  ]
}
