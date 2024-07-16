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
        protocol \(raw: emptyProtocolName): \(protocolDec.name){}
        """)
    let vars = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(VariableDeclSyntax.self) }
    let funcs = protocolDec.memberBlock.members
        .map(\.decl)
        .compactMap { $0.as(FunctionDeclSyntax.self) }

    emptyProtocol.attributes.append(.attribute(
        .init(stringLiteral: "@Faked_Imp")))
    
    // Copy in the properties and functions
    emptyProtocol.memberBlock.members = .init {
      for property in vars { property }
      for function in funcs { function }
    }
    
    let fakeStruct = try SwiftSyntax.StructDeclSyntax(
      """
        struct Fake\(protocolDec.name): Empty\(protocolDec.name) {}
      """
    )
    
    return [DeclSyntax(emptyProtocol),
            DeclSyntax(fakeStruct)]
  }
}

public struct FakedImpMacro: ExtensionMacro
{
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

    let members = try protocolDec.memberBlock.members.map {
      member -> DeclSyntaxProtocol in
      if let property = member.decl.as(VariableDeclSyntax.self) {
        return try defaultPropertyImp(property)
      }
      else if let function = member.decl.as(FunctionDeclSyntax.self) {
        return try defaultFunctionImp(function)
      }
      throw Error.invalidMember
    }
    
    return [ExtensionDeclSyntax(extendedType: type, memberBlock: .init() {
      for member in members { member }
    })]
  }
  
  static func defaultPropertyImp(_ property: VariableDeclSyntax) throws -> VariableDeclSyntax
  {
    guard let binding = property.bindings.first
    else { throw Error.bindingCount }
    let type = binding.typeAnnotation!.type.description
    
    if let typeIdentifier = binding.typeAnnotation!.type.as(IdentifierTypeSyntax.self) {
      guard let emptyValue = defaultIdentifierValue(typeIdentifier)
      else { throw Error.unhandledType }
      
      let newProp = try!  VariableDeclSyntax(
        """
          var \(binding.pattern.detached): \(raw: type) { \(raw: emptyValue) }
        """
      )
      
      return newProp
    }
    throw Error.unhandledType
  }
  
  static func defaultFunctionImp(_ function: FunctionDeclSyntax) throws -> FunctionDeclSyntax
  {
    var defaultValue = ""
    
    if let clause = function.signature.returnClause {
      if let identifier = clause.type.as(IdentifierTypeSyntax.self) {
        defaultValue = defaultIdentifierValue(identifier) ?? ""
      }
    }
    
    var copy = function
    
    copy.body = .init(statements: .init(stringLiteral: defaultValue))
    return copy
  }
  
  static func defaultIdentifierValue(_ identifier: IdentifierTypeSyntax) -> String?
  {
    switch identifier.name.text {
      case "Int":
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
