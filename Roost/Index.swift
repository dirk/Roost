import Foundation

private let LINE_FEED: UInt8 = 10

class Index {
  
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
  }
}
