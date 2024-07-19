import Foundation
import SwiftSyntax

extension SyntaxProtocol
{
  var withLeadingSpace: Self
  {
    var copy = self
    copy.leadingTrivia = .space
    return copy
  }

  var withTrailingSpace: Self
  {
    var copy = self
    copy.trailingTrivia = .space
    return copy
  }
  
  var withTrailingNewline: Self
  {
    var copy = self
    copy.trailingTrivia = .newline
    return copy
  }
  
  var commentsStripped: Self
  {
    var copy = self
    copy.leadingTrivia = Trivia(pieces: leadingTrivia.filter { !$0.isComment })
    copy.trailingTrivia = Trivia(pieces: trailingTrivia.filter { !$0.isComment })
    return copy
  }
  
  func withIndent(_ indent: Trivia) -> Self
  {
    var copy = self
    copy.leadingTrivia = indent
    return copy
  }
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
