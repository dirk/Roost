import Foundation
import MessagePack

private let LINE_FEED: UInt8 = 10

class Index {

  static var HeaderRegex: NSRegularExpression! {
    do {
      return try NSRegularExpression(pattern: "Roost Index Version (\\d+)",
                                     options: NSRegularExpressionOptions())
    } catch {
      printAndExit("Unable to compiled regular expression: \(error)")
      return nil
    }
  }

  struct Version {
    let version: String
    let description: String
  }

  struct Package {
    let name: String
    let version: String
    let versions: Array<Version>
  }

  var packages = Dictionary<String, Package>()

  init(dictionary: [MessagePackValue : MessagePackValue]) {
    for (nameValue, packageValue) in dictionary {
      let name    = nameValue.stringValue!
      let package = packageValue.dictionaryValue!

      let version = package["version"]!.stringValue!
      let versions = package["versions"]!.arrayValue!.map {
        (v: MessagePackValue) -> Version in

        let version     = v["version"]!.stringValue!
        let description = v["description"]!.stringValue!

        return Version(version: version, description: description)
      }

      packages[name] = Package(name: name,
                               version: version,
                               versions: versions)
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

  class func read(path: String) -> Index! {
    let (headerData, payloadData) = readHeaderAndPayload(path)
    var version: Int

    guard let header = NSString(data: headerData, encoding: NSUTF8StringEncoding) else {
      printAndExit("Unable to read Index header data"); return nil }

    version = parseAndCheckHeader(header as String)

    print("Loading Index version \(version) ... ", terminator: "")

    guard let value = MessagePack.unpack(payloadData) else {
      printAndExit("Error unpacking Index"); return nil }

    guard let dictionary = value.dictionaryValue else {
      printAndExit("Error reading Index; expected dictionary"); return nil }

    print("Done")
    return Index(dictionary: dictionary)
  }

  class func readHeaderAndPayload(path: String) -> (NSData!, NSData!) {
    guard let data = NSData(contentsOfFile: path) else {
      printAndExit("Unable to read Index file: \(path)"); return (nil, nil) }

    var bytes = Array<UInt8>(count: data.length, repeatedValue: 0)
    data.getBytes(&bytes, length: data.length)

    let separatorIndex: Int! = bytes.indexOf(LINE_FEED)!

    if separatorIndex == nil {
      printAndExit("Unable to find separator \"\\n\" in Index")
    }

    var headerBytes  = Array<UInt8>(bytes[0..<separatorIndex])
    var payloadBytes = Array<UInt8>(bytes[(separatorIndex + 1)..<data.length])

    let headerData  = NSData(bytes: &headerBytes, length: separatorIndex)
    let payloadData = NSData(bytes: &payloadBytes,
                             length: (data.length - separatorIndex) - 1)

    return (headerData, payloadData)
  }

  class func parseAndCheckHeader(header: String) -> Int {
    var version: Int

    guard let matches = HeaderRegex.firstMatchInString(header,
                                                       options: NSMatchingOptions(),
                                                       range: NSMakeRange(0, header.characters.count))
    else {
      printAndExit("Unable to parse Index header"); return 0
    }

    let versionRange = matches.rangeAtIndex(1)
    let versionString = (header as NSString).substringWithRange(versionRange)

    version = (versionString as NSString).integerValue

    if version != 1 {
      printAndExit("Unable to parse Index version \(version)"); return 0
    }

    return version
  }
}
