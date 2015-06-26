import Foundation

public class Task {
  let task: NSTask
  let inputPipe: NSPipe
  let outputPipe: NSPipe
  let errorPipe: NSPipe

  public var arguments: [AnyObject] {
    get {
      return task.arguments 
    }
    set {
      task.arguments = newValue
    }
  }

  var launched: Bool = false
  var exited: Bool = false

  public var outputString: String
  public var errorString:  String

  public init(_ launchPath: String) {
    task = NSTask()
    task.launchPath = launchPath

    inputPipe  = NSPipe()
    outputPipe = NSPipe()
    errorPipe  = NSPipe()

    outputString = ""
    errorString  = ""
  }

  public func launch() {
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle  = errorPipe.fileHandleForReading
    
    outputHandle.readabilityHandler = { (handle) in
      let data = handle.availableData
      self.outputString += NSString(data: data, encoding: NSUTF8StringEncoding)! as String
    }
    errorHandle.readabilityHandler = { (handle) in
      let data = handle.availableData
      self.errorString += NSString(data: data, encoding: NSUTF8StringEncoding)! as String 
    }

    outputHandle.readToEndOfFileInBackgroundAndNotify()
    errorHandle.readToEndOfFileInBackgroundAndNotify()

    task.launch()

    launched = true
  }

  public func launchAndWait() {
    launch()

    task.waitUntilExit()

    exited = true
  }

  public func hasAnyOutput() -> Bool {
    let outputTrimmed = outputString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    let errorTrimmed  = errorString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())

    return (count(outputTrimmed) > 0 || count(errorTrimmed) > 0)
  }
}
