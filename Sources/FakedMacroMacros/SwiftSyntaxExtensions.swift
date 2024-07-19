import Foundation
import SwiftSyntax

extension SyntaxProtocol
{
  func copy<T>(with path: WritableKeyPath<Self, T>, as value: T) -> Self
  {
    var copy = self
    copy[keyPath: path] = value
    return copy
  }
  
  var withLeadingSpace: Self
  { copy(with: \.leadingTrivia, as: .space) }

  var withTrailingSpace: Self
  { copy(with: \.trailingTrivia, as: .space) }

  var withTrailingNewline: Self
  { copy(with: \.trailingTrivia, as: .newline) }
  
  func withIndent(_ indent: Trivia) -> Self
  { copy(with: \.leadingTrivia, as: indent) }
}

extension TriviaPiece
{
  var isComment: Bool
  {
    switch self {
      case .blockComment, .docBlockComment, .lineComment, .docLineComment:
        return true
      default:
        return false
    }
  }
}
