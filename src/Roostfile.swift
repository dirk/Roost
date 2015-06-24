import Foundation

private let commentToken = "#"
private let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
private let whitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()

class Roostfile {
  var name: String!
  var directory: String!
  var sources: [String] = []

  func parseFromString(string: String) {
    let stringAsNSString = string as NSString

    var lineNumber = 0

    stringAsNSString.enumerateLinesUsingBlock { (line, stop) in
      // Map names to processors
      let map = [
        "name": self.parseName,
        "sources": self.parseSources
      ]

      let scanner = NSScanner(string: line)
      lineNumber += 1

      // Skip lines beginning with a comment
      if scanner.scanString(commentToken, intoString: nil) {
        return
      }
      // Skip all whitespace
      if scanner.atEnd {
        return
      }

      // TODO: Allow multi-line statements

      for (command, action) in map {
        if scanner.scanString(command, intoString: nil) {
          action(scanner, lineNumber)
          break
        }
      }
      if scanner.atEnd { return }

      let token = self.scanWord(scanner)
      println("Unrecognized token '\(token!)' on line \(lineNumber)")
      exit(1)
    }
  }

  func parseName(scanner: NSScanner, _ lineNumber: Int) {
    let token = scanWord(scanner)

    if token == nil {
      println("Missing name on line \(lineNumber)")
      exit(1)
    }
    let name = token!
  }

  func parseSources(scanner: NSScanner, _ lineNumber: Int) {
    sources = scanWords(scanner)

    if sources.count == 0 {
      println("Must have at least one source in sources on line \(lineNumber)")
      exit(1)
    }
  }

  func validate() {
    // TODO: Implement some validations
    return
  }

  func inspect() {
    println("name \(name)")
    println("sources \(sources)")
  }


  private func scanWord(scanner: NSScanner) -> String? {
    var token: NSString?
    let scanned = scanner.scanUpToCharactersFromSet(whitespaceAndNewlineCharacterSet, intoString: &token)

    return scanned ? (token as String?) : nil
  }

  private func scanWords(scanner: NSScanner) -> [String] {
    var words: [String] = []

    while true {
      let word = scanWord(scanner)

      if word == nil { break }

      words.append(word!)
    }

    return words
  }

  private func consumeWhitespace(scanner: NSScanner) -> Bool {
    return scanner.scanCharactersFromSet(whitespaceCharacterSet, intoString: nil)
  }

}// class Roostfile

