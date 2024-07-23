import Foundation
import SwiftDiagnostics

enum FakedError: Swift.Error, DiagnosticMessage
{
  case bindingCount
  case defaultVarFunc
  case notAProtocol
  case invalidMember
  case invalidDefault
  case unhandledType
  case wrongTypeSpecifier

  var message: String
  {
    switch self {
      case .bindingCount:
        "Each `var` must have exactly one binding"
      case .defaultVarFunc:
        "FakeDefault macro must be attached to a var or func declaration"
      case .notAProtocol:
        "Macro must be attached to a protocol"
      case .invalidMember:
        "Unsupported protocol member found"
      case .invalidDefault:
        "Invalid default value"
      case .unhandledType:
        "Result type not supported"
      case .wrongTypeSpecifier:
        "Types must be specified as a string literal and a type such as `Int.self`"
    }
  }
  
  var diagnosticID: MessageID { .init(domain: "FakedMacro", id: "\(self)") }
  
  var severity: DiagnosticSeverity { .error }
}

enum FakedWarning: DiagnosticMessage
{
  case typeNotFound(String)
  
  var message: String
  {
    switch self {
      case .typeNotFound(let type):
        "Associated type \(type) not found"
    }
  }
  
  var severity: DiagnosticSeverity { .warning }
  
  var diagnosticID: MessageID
  { .init(domain: "FakedMacro", id: "warn-\(self)") }
}
