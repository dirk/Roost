import Foundation

class Roostfile {
  let commentToken = "#"

  let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
  let whitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()

  func parseFromString(string: String) {
    let stringAsNSString = string as NSString

    var lineNumber = 0

    stringAsNSString.enumerateLinesUsingBlock { (line, stop) in
      // Map names to processors
      let map = [
        "name": { self.parseName($0, lineNumber: lineNumber) }
      ]

      let scanner = NSScanner(string: line)
      lineNumber += 1

      // Skip lines beginning with a comment
      if scanner.scanString(self.commentToken, intoString: nil) {
        return
      }
      // Skip all whitespace
      if scanner.atEnd {
        return
      }

      // TODO: Allow multi-line statements

      for (command, action) in map {
        if scanner.scanString(command, intoString: nil) {
          action(scanner)
          break
        }
      }
      if scanner.atEnd { return }

      let token = self.scanWord(scanner)
      println("Unrecognized token '\(token!)' on line \(lineNumber)")
      exit(1)
    }
  }

  func parseName(scanner: NSScanner, lineNumber: Int) {
    let token = scanWord(scanner)

    if token == nil {
      println("Missing name on line \(lineNumber)")
      exit(1)
    }
    let name = token!

    println("name \(name)")
  }

  private func scanWord(scanner: NSScanner) -> String? {
    var token: NSString?
    let scanned = scanner.scanUpToCharactersFromSet(whitespaceAndNewlineCharacterSet, intoString: &token)

    return scanned ? (token as String?) : nil
  }

  private func consumeWhitespace(scanner: NSScanner) -> Bool {
    return scanner.scanCharactersFromSet(whitespaceCharacterSet, intoString: nil)
  }

}// class Roostfile

