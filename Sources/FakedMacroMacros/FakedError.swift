import Foundation
import SwiftDiagnostics

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
