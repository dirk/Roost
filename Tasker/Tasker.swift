import Foundation

private func readPipeToEnd(pipe: NSPipe) -> NSData {
  let handle = pipe.fileHandleForReading
  return handle.readDataToEndOfFile()
}

extension NSData {
  func toUTF8String() -> String {
    return NSString(data: self, encoding: NSUTF8StringEncoding)! as String
  }
}

public class Task {

  public let task: NSTask

  public var arguments: [AnyObject] {
    get { return task.arguments }
    set { task.arguments = newValue }
  }

  let inputPipe: NSPipe
  let outputPipe: NSPipe
  let errorPipe: NSPipe

  public var launched: Bool = false
  public var exited: Bool = false
  public var exitStatus: Int = -1

  public var outputData:   NSData!
  public var errorData:    NSData!
  public var outputString: String
  public var errorString:  String

  public init(_ launchPath: String) {
    task = NSTask()
    task.launchPath = launchPath

    inputPipe  = NSPipe()
    outputPipe = NSPipe()
    errorPipe  = NSPipe()

    // Set the pipes on the task
    task.standardInput  = inputPipe
    task.standardOutput = outputPipe
    task.standardError  = errorPipe

    outputString = ""
    errorString  = ""
  }

  public func launch() {
    task.launch()

    launched = true
  }

  public func launchAndWait() {
    launch()

    task.waitUntilExit()

    outputData = readPipeToEnd(outputPipe)
    errorData  = readPipeToEnd(errorPipe)

    outputString = outputData!.toUTF8String()
    errorString  = errorData!.toUTF8String()

    exited = true
    exitStatus = Int(task.terminationStatus)
  }

  public func hasAnyOutput() -> Bool {
    let outputTrimmed = outputString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    let errorTrimmed  = errorString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())

    return (count(outputTrimmed) > 0 || count(errorTrimmed) > 0)
  }
}
