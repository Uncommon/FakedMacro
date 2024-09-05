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
      context.diagnose(.init(node: member, message: FakedError.unhandledType))
      throw FakedError.unhandledType
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
        modifiers: protocolDec.modifiers,
        extensionKeyword: .keyword(.extension, trailingTrivia: .space),
        extendedType: type,
        memberBlock: memberBlock)]
  }
  
  static func defaultPropertyImp(_ property: VariableDeclSyntax,
                                 isFirst: Bool) throws -> VariableDeclSyntax
  {
    guard let binding = property.bindings.first
    else { throw FakedError.bindingCount }
    let type = binding.typeAnnotation!.type.trimmedDescription
    let defaultValue: String
    let hasSetter = {
      if case let .accessors(accessors) = binding.accessorBlock?.accessors {
        accessors.contains { $0.accessorSpecifier.trimmedDescription == "set" }
      }
      else {
        false
      }
    }()
    
    if let defaultMacro = try defaultMacroValue(for: property.attributes) {
      defaultValue = defaultMacro
    }
    else if let type = binding.typeAnnotation?.type,
            let typeDefault = Self.defaultValue(for: type) {
      defaultValue = typeDefault
    }
    else {
      defaultValue = ".fakeDefault()"
    }
    
    let body = hasSetter
        ? "{ get { \(defaultValue) } set {} }"
        : "{ \(defaultValue) }"
    var decl = try VariableDeclSyntax(
      """
        var \(binding.pattern.detached): \(raw: type) \(raw: body)
      """
      )
    let trivia = Trivia(pieces:
        property.leadingTrivia.pieces
        .filter { !$0.isNewline })
    
    decl.bindingSpecifier = .keyword(.var,
                                     leadingTrivia: trivia,
                                     trailingTrivia: .space)
    return decl
  }
  
  /// Returns the value from a @FakeDefault macro, if any
  static func defaultMacroValue(for attributes: AttributeListSyntax) throws
    -> String?
  {
    if let defaultMacro = attributes
        .compactMap({
          (attribute: AttributeListSyntax.Element) -> AttributeSyntax? in
          if case let .attribute(attribute) = attribute {
            return attribute
          }
          else {
            return nil
          }
        })
        .first(where: {
          return $0.attributeName.trimmedDescription == "FakeDefault"
        }) {
      if case let .argumentList(args) = defaultMacro.arguments,
         let firstArg = args.first {
        if firstArg.label?.trimmedDescription == "exp",
           let expString = firstArg.expression.as(StringLiteralExprSyntax.self) {
          return expString.representedLiteralValue
        }
        else {
          return firstArg.expression.trimmedDescription
        }
      }
      else {
        throw FakedError.invalidDefault
      }
    }
    else {
      return nil
    }
  }
  
  /// Returns the standard default value for the given type
  static func defaultValue(for type: TypeSyntax) -> String?
  {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      return defaultIdentifierValue(identifier)
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
      defaultValue = try
          defaultMacroValue(for: function.attributes) ??
          Self.defaultValue(for: clause.type) ??
          ".fakeDefault()"
    }
    
    var copy = function
    let leadingTrivia = copy.attributes.isEmpty ?
        copy.leadingTrivia : copy.attributes.leadingTrivia
    
    copy.body = .init(leadingTrivia: .space,
                      statements: .init(
                        stringLiteral: defaultValue.isEmpty ? "" :
                          " \(defaultValue) "))
    copy.attributes = copy.attributes.filter {
      switch $0 {
        case let .attribute(attribute):
          attribute.attributeName.trimmedDescription != "FakeDefault"
        default: true
      }
    }
    copy.leadingTrivia =
        Trivia(pieces: leadingTrivia.filter { !$0.isNewline })
    
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
