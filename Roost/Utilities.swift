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

  let created = fileManager.createDirectoryAtPath(path,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil,
                                                  error: nil)

  return created
}

public func readFile(path: String) -> String {
  let url = NSURL(fileURLWithPath: path)!
  var error: NSError?

  let contents = NSString(contentsOfURL: url, encoding: NSUTF8StringEncoding, error: &error)

  if contents == nil {
    let errorString = error!.localizedDescription
    printAndExit("Error reading file: \(errorString)")
  }
  return contents! as String
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
  var error: NSError?
  let manager = NSFileManager.defaultManager()

  let attributes = manager.attributesOfItemAtPath(path, error: &error)
  if attributes == nil { return nil }

  let maybeDate: AnyObject? = attributes![NSFileModificationDate]
  return maybeDate as! NSDate?
}

func announceAndRunTask(announcement: String, #arguments: [String], #finished: String) {
  func normalAnnouncer(block: () -> (Task)) {
    print(announcement)
    stdoutFlush()

    let task = block()

    if !task.hasAnyOutput() {
      print("\u{001B}[2K") // Clear the whole line
      print("\r") // Reset cursor to the beginning of line
      println(finished)
    }
  }
  func verboseAnnouncer(block: () -> (Task)) {
    println(announcement)
    println(" ".join(arguments))

    block()
  }

  let announcer = Flags.Verbose ? verboseAnnouncer : normalAnnouncer

  announcer() {
    let task = Task("/usr/bin/env")
    task.arguments = arguments

    task.launchAndWait()

    if task.hasAnyOutput() {
      println()

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

private func stdoutFlush() {
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

    var hash = NSMutableString()
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
