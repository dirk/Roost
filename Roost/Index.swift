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

  class func read(path: String) {
    let (headerData, payloadData) = readHeaderAndPayload(path)
    var version: Int

    if let header = NSString(data: headerData, encoding: NSUTF8StringEncoding) {
      version = parseAndCheckHeader(header as String)
    } else {
      return printAndExit("Unable to read Index header data")
    }

    print("Loading Index version \(version)... ")

    if let value = MessagePack.unpack(payloadData) {
      if let dictionary = value.dictionaryValue {
        let _ = Index(dictionary: dictionary)
        // TODO: Use the index!

        print("Done")
        return
      }
    }
    print("Error reading MessagePack data")
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

    if let matches = HeaderRegex.firstMatchInString(header,
                                                    options: NSMatchingOptions(),
                                                    range: NSMakeRange(0, header.characters.count)) {
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
