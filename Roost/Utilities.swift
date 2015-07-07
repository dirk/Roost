import Foundation
import Tasker

public func currentDirectoryPath() -> String {
  return (NSFileManager().currentDirectoryPath)
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

public func printAndExit(string: String, status: Int32 = 1) {
  println(string)
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
  print(announcement)
  stdoutFlush()

  let task = Task("/bin/sh")
  task.arguments = arguments

  task.launchAndWait()

  print("\u{001B}[2K") // Clear the whole line
  print("\r") // Reset cursor to the beginning of line

  if task.hasAnyOutput() {
    println(task.outputString)
    println(task.errorString)
  } else {
    println(finished)
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

extension NSDate {
  func isNewerThan(other: NSDate) -> Bool {
    return (self.compare(other) == NSComparisonResult.OrderedDescending) ? true : false
  }
}
