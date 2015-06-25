import Foundation

private let commentToken = "#"

let WhitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
let WhitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()

class Roostfile {
  var name: String!
  var directory: String!
  var sources: [String] = []

  func parseFromString(string: String) {
    // Map names to processors
    let map = [
      "name":    self.parseName,
      "sources": self.parseSources,
      "module":  self.parseModule
    ]

    let stringAsNSString = string as NSString

    var lineNumber = 0
    
    var scanner = NSScanner(string: string)
    scanner.charactersToBeSkipped = WhitespaceCharacterSet

    commandLoop: while !scanner.atEnd {
      consumeCommentsAndNewlines(scanner)

      let maybeWord = scanWord(scanner)

      if maybeWord == nil {
        if scanner.atEnd { return }

        println("Ran out of input")
        exit(1)
      }

      let word = maybeWord!

      for (command, action) in map {
        if word == command {
          // println("Action found for \(word)")
          action(scanner, 0)
          continue commandLoop
        }
      }

      println("Unrecognied token `\(word)`")
      exit(1)
    }


    /*
    stringAsNSString.enumerateLinesUsingBlock { (line, stop) in
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
    */
  }

  func parseName(scanner: NSScanner, _ lineNumber: Int) {
    let token = scanWord(scanner)

    if token == nil {
      println("Missing name on line \(lineNumber)")
      exit(1)
    }
    name = token!
  }

  func parseSources(scanner: NSScanner, _ lineNumber: Int) {
    sources = scanWords(scanner)

    if sources.count == 0 {
      println("Must have at least one source in sources on line \(lineNumber)")
      exit(1)
    }
  }

  func parseModule(scanner: NSScanner, _ lineNumber: Int) {
    mustScanWord(scanner, "{")

    scanner.scanUpToString("}", intoString: nil)
    scanner.scanString("}", intoString: nil)
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
    let scanned = scanner.scanUpToCharactersFromSet(WhitespaceAndNewlineCharacterSet, intoString: &token)

    return scanned ? (token as String?) : nil
  }

  private func mustScanWord(scanner: NSScanner, _ expectedWord: String) {
    let word = scanWord(scanner)

    if word == nil {
      println("Expected word"); exit(1)
    }
    if word != expectedWord {
      println("Expected '\(expectedWord)', got '\(word)'"); exit(1)
    }
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

  private let newlineCharacterSet = NSCharacterSet(charactersInString: "\n")

  private func consumeCommentsAndNewlines(scanner: NSScanner) {
    while true {
      // Gulp up any newlines
      scanner.scanCharactersFromSet(newlineCharacterSet, intoString: nil)

      // We encountered a non-comment
      if !scanner.scanString(commentToken, intoString: nil) {
        return
      }
      scanner.scanUpToCharactersFromSet(newlineCharacterSet, intoString: nil)
    }
  }

  private func consumeWhitespace(scanner: NSScanner) -> Bool {
    return scanner.scanCharactersFromSet(WhitespaceCharacterSet, intoString: nil)
  }

}// class Roostfile

