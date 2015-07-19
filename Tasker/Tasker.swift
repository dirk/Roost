import Foundation

public class Task {

  public let task: NSTask
  public var arguments: [AnyObject] {
    get { return task.arguments }
    set { task.arguments = newValue }
  }

  let inputPipe: NSPipe
  let outputPipe: NSPipe
  let errorPipe: NSPipe

  var launched: Bool = false
  var exited: Bool = false

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

    func readPipe(pipe: NSPipe) -> NSData {
      let handle = pipe.fileHandleForReading
      return handle.readDataToEndOfFile()
    }
    func dataToString(data: NSData) -> String {
      return NSString(data: data, encoding: NSUTF8StringEncoding)! as String
    }

    outputData = readPipe(outputPipe)
    errorData  = readPipe(errorPipe)

    outputString = dataToString(outputData!)
    errorString  = dataToString(errorData!)

    exited = true
  }

  public func hasAnyOutput() -> Bool {
    let outputTrimmed = outputString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    let errorTrimmed  = errorString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())

    return (count(outputTrimmed) > 0 || count(errorTrimmed) > 0)
  }
}
