import Foundation

private let LINE_FEED: UInt8 = 10

class Index {

  static var HeaderRegex: NSRegularExpression! {
    var error: NSError?

    if let headerRegex = NSRegularExpression(pattern: "Roost Index Version (\\d+)",
                                             options: .allZeros,
                                             error: &error) {
      return headerRegex
    } else {
      printAndExit("Unable to compiled regular expression: \(error)")
      return nil
    }
  }

  class func findIndexFile() -> String {
    let home = NSHomeDirectory()
    let directory = "\(home)/.roost"

    if !directoryExists(directory) {
      if !createDirectoryAtPath(directory) {
        printAndExit("Unable to create data directory: \(directory)")
      }
    }

    let path = "\(directory)/Index.bin"

    if !fileExists(path) {
      printAndExit("Missing index file: \(path)")
    }

    return path
  }

  class func read(path: String) {
    var (headerData, payloadData) = readHeaderAndPayload(path)
    var version: Int

    if let header = NSString(data: headerData, encoding: NSUTF8StringEncoding) {
      version = parseAndCheckHeader(header as String)
    } else {
      return printAndExit("Unable to read Index header data")
    }

    println("Loading Index version \(version)... ")
  }

  class func readHeaderAndPayload(path: String) -> (NSData, NSData) {
    var data: NSData = NSData()

    if let foundData = NSData(contentsOfFile: path) {
      data = foundData
    } else {
      printAndExit("Unable to read Index file: \(path)")
    }

    var bytes = Array<UInt8>(count: data.length, repeatedValue: 0)
    data.getBytes(&bytes, length: data.length)

    let separatorIndex: Int! = find(bytes, LINE_FEED)!

    if separatorIndex == nil {
      printAndExit("Unable to find separator \"\\n\" in Index")
    }

    var headerBytes  = Array<UInt8>(bytes[0..<separatorIndex])
    var payloadBytes = Array<UInt8>(bytes[(separatorIndex + 1)..<data.length])

    var headerData  = NSData(bytes: &headerBytes, length: separatorIndex)
    var payloadData = NSData(bytes: &payloadBytes,
                             length: (data.length - separatorIndex) - 1)

    return (headerData, payloadData)
  }

  class func parseAndCheckHeader(header: String) -> Int {
    var version: Int

    if let matches = HeaderRegex.firstMatchInString(header,
                                                    options: .allZeros,
                                                    range: NSMakeRange(0, count(header))) {
      let versionRange = matches.rangeAtIndex(1)
      let versionString = (header as NSString).substringWithRange(versionRange)

      version = (versionString as NSString).integerValue
    } else {
      printAndExit("Unable to parse Index header"); return 0
    }

    if version != 1 {
      printAndExit("Unable to parse Index version \(version)"); return 0
    }

    return version
  }
}
