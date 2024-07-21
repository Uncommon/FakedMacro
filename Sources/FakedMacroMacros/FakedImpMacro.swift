import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

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
      defaultValue = try Self.defaultValue(for: type) ??
        { throw FakedError.unhandledType }()
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
  
  static func defaultValue(for type: TypeSyntax) -> String?
  {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      return defaultIdentifierValue(identifier) ?? ""
    }
    else if type.is(ArrayTypeSyntax.self) {
      return "[]"
    }
    else if type.is(DictionaryTypeSyntax.self) {
      return "[:]"
    }
    else if type.is(OptionalTypeSyntax.self) {
      return "nil"
    }
    return nil
  }
  
  static func defaultFunctionImp(_ function: FunctionDeclSyntax) throws -> FunctionDeclSyntax
  {
    var defaultValue = ""
    
    if let clause = function.signature.returnClause {
      defaultValue = try Self.defaultValue(for: clause.type) ??
        { throw FakedError.unhandledType }()
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
      case "Int", "Float", "Double",
           "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "UInt128",
           "Int8", "Int16", "Int32", "Int64", "Int128",
           "Float16", "Float32", "Float64", "Float80":
        return "0"
      case "String":
        return #""""#
      case "Bool":
        return "false"
      case "Set": // skip checking the generic clause
        return "[]"
      case "AnySequence":
        guard let generic = identifier.genericArgumentClause,
              let first = generic.arguments.first?.argument.as(IdentifierTypeSyntax.self)
        else { return nil }
        return ".init(Array<\(first.name.text)>())"
      default:
        return nil
    }
  }
}
