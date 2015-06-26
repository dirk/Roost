import Foundation
import Tasker

class Package {
  var roostfile: Roostfile

  var sourceFiles: [String] = []

  init(_ r: Roostfile) {
    roostfile = r

    for sourceDirectory in roostfile.sources {
      if !(sourceDirectory as NSString).hasSuffix("/") {
        println("Cannot handle directory like '\(sourceDirectory)'")
        continue
      }

      let baseDirectory = roostfile.directory as NSString
      let directory = baseDirectory.stringByAppendingPathComponent(sourceDirectory)

      sourceFiles.extend(scanDirectoryForSources(directory))
    }
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

  func scanDirectoryForSources(directory: String) -> [String] {
    let fileManager = NSFileManager()
    let enumerator = fileManager.enumeratorAtPath(directory)!

    var files = [String]()

    for file in enumerator {
      if !file.hasSuffix(".swift") { continue }

      let filePath = directory.stringByAppendingPathComponent(file as! String)

      files.append(filePath)
    }

    return files
  }// scanSources()

}
