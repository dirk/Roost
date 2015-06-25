import Foundation
import Tasker

class Package {
  var roostfile: Roostfile

  var sourceFiles: [String] = []

  init(_ r: Roostfile) {
    roostfile = r

    scanSources()
  }

  func compile() {
    let binFilePath = "bin/\(roostfile.name.lowercaseString)"

    var arguments: [String] = ["swiftc"]
    
    let sdkPath = getSDKPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)
    arguments.append("-sdk")
    arguments.append(sdkPath)

    // Compile all of the sources
    arguments.extend(sourceFiles)

    // And set the location of the output executable
    arguments.append("-o")
    arguments.append(binFilePath)

    let argumentsString = " ".join(arguments)

    let outputPipe  = NSPipe()
    let errorPipe   = NSPipe()
    let compileTask = NSTask()
    compileTask.launchPath = "/bin/sh"
    compileTask.arguments = ["-c", argumentsString]
    compileTask.standardOutput = outputPipe
    compileTask.standardError  = errorPipe

    compileTask.launch()

    print(readPipeToString(outputPipe))
    print(readPipeToString(errorPipe))

    println("Compiled \(roostfile.name) to \(binFilePath)")
  }

  private func readPipeToString(pipe: NSPipe) -> NSString {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return NSString(data: data, encoding: NSUTF8StringEncoding)!
  }

  func getSDKPath() -> String {
    // TODO: Implement generalized NSTask abstraction struct
    let outputPipe = NSPipe()
    let task = NSTask()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", "xcrun --show-sdk-path"]
    task.standardOutput = outputPipe

    task.launch()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return NSString(data: outputData, encoding: NSUTF8StringEncoding) as! String
  }

  private func scanSources() {
    let directory = roostfile.directory as NSString
    let fileManager = NSFileManager()

    for source in roostfile.sources {
      if !(source as NSString).hasSuffix("/") {
        println("Cannot handle source pattern '\(source)'")
        continue
      }

      let path = directory.stringByAppendingPathComponent(source)
      let enumerator = fileManager.enumeratorAtPath(path)!

      for file in enumerator {
        let filePath = path.stringByAppendingPathComponent(file as! String)
        sourceFiles.append(filePath)
      }
    }
  }// scanSources()

}
