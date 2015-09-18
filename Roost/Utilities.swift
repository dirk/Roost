import Foundation
import Tasker

public func currentDirectoryPath() -> String {
  return (NSFileManager().currentDirectoryPath)
}

private enum FileStatus {
  case Missing
  case File
  case Directory
}

private func getFileStatus(path: String) -> FileStatus {
  let fileManager = NSFileManager.defaultManager()
  var isDirectory: ObjCBool = false

  if fileManager.fileExistsAtPath(path, isDirectory: &isDirectory) {
    if isDirectory {
      return .Directory
    }
    return .File
  }
  return .Missing
}

public func directoryExists(path: String) -> Bool {
  switch getFileStatus(path) {
    case .Directory:
      return true
    default:
      return false
  }
}

public func fileExists(path: String) -> Bool {
  switch getFileStatus(path) {
    case .File:
      return true
    default:
      return false
  }
}

public func createDirectoryAtPath(path: String) -> Bool {
  let fileManager = NSFileManager.defaultManager()

  do {
    try fileManager.createDirectoryAtPath(path,
                                          withIntermediateDirectories: true,
                                          attributes: nil)
    return true
  } catch {
    return false
  }
}

public func readFile(path: String) -> String {
  let url = NSURL(fileURLWithPath: path)

  do {
    return try NSString(contentsOfURL: url, encoding: NSUTF8StringEncoding) as String
  } catch {
    printAndExit("Error reading file: \(error)")
    return ""
  }
}

private let stderr = NSFileHandle.fileHandleWithStandardError()

/**
  Print the string to standard error and exit immediately.
*/
public func printAndExit(string: String, status: Int32 = 1) {
  let data = string.dataUsingEncoding(NSUTF8StringEncoding)

  stderr.writeData(data!)
  stderr.writeData("\n".dataUsingEncoding(NSUTF8StringEncoding)!)
  exit(status)
}

public func getFileModificationDate(path: String) -> NSDate? {
  let manager = NSFileManager.defaultManager()

  if let attributes = try? manager.attributesOfItemAtPath(path) {
    return attributes[NSFileModificationDate] as! NSDate?
  } else {
    return nil
  }
}

func announceAndRunTask(announcement: String, arguments: [String], finished: String) -> Int {
  func normalAnnouncer(block: () -> (Task)) -> Int {
    print(announcement, terminator: "")
    stdoutFlush()

    let task = block()

    if !task.hasAnyOutput() {
      print("\u{001B}[2K", terminator: "") // Clear the whole line
      print("\r", terminator: "") // Reset cursor to the beginning of line
      print(finished)
    }
    return task.exitStatus
  }
  func verboseAnnouncer(block: () -> (Task)) -> Int {
    print(announcement)
    print(arguments.joinWithSeparator(" "))

    let task = block()
    return task.exitStatus
  }

  let announcer = Flags.Verbose ? verboseAnnouncer : normalAnnouncer

  return announcer() {
    let task = Task("/usr/bin/env")
    task.arguments = arguments

    task.launchAndWait()

    if task.hasAnyOutput() {
      print("")

      if let output = task.outputData {
        NSFileHandle.fileHandleWithStandardOutput().writeData(output)
      }
      if let error = task.errorData {
        NSFileHandle.fileHandleWithStandardError().writeData(error)
      }
    }

    return task
  }
}

func stdoutFlush() {
  fflush(__stdoutp)
}


private var SDKPath: String!

public func getSDKPath() -> String {
  if let path = SDKPath {
    return path
  }

  // TODO: Implement generalized NSTask abstraction struct
  let outputPipe = NSPipe()
  let task = NSTask()
  task.launchPath = "/bin/sh"
  task.arguments = ["-c", "xcrun --show-sdk-path"]
  task.standardOutput = outputPipe

  task.launch()

  let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
  let path = NSString(data: outputData, encoding: NSUTF8StringEncoding) as! String

  // Memoize and return
  SDKPath = path
  return path
}

public func getSDKPlatformPath() -> String {
  let task = Task("/bin/sh")
  task.arguments = ["-c", "xcrun --sdk macosx --show-sdk-platform-path"]

  task.launchAndWait()

  if !task.hasAnyOutput() {
    printAndExit("Failed to look up SDK platform path")
  }

  return task.outputString
}

extension NSDate {
  func isNewerThan(other: NSDate) -> Bool {
    return (self.compare(other) == NSComparisonResult.OrderedDescending) ? true : false
  }
}

extension String {
  func contains(other: String) -> Bool {
    return self.rangeOfString(other) != nil
  }

  func computeMD5() -> String {
    let cString = cStringUsingEncoding(NSUTF8StringEncoding)
    let cStringLength = CUnsignedInt(lengthOfBytesUsingEncoding(NSUTF8StringEncoding))

    let digestLength = Int(CC_MD5_DIGEST_LENGTH)
    let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLength)

    CC_MD5(cString!, cStringLength, result)

    let hash = NSMutableString()
    for i in 0..<digestLength {
      hash.appendFormat("%02x", result[i])
    }

    result.destroy()
    return String(hash)
  }
}

func md5File(path: String) -> String {
  return readFile(path).computeMD5()
}
