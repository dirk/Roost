import Foundation

class Package {
  var roostfile: Roostfile
  var sourceFiles: [String] = []
  var lastModificationDate: NSDate = NSDate()
  var modules: [Package.Module] = []

  init(_ r: Roostfile) {
    roostfile            = r
    sourceFiles          = scanSourcesDirectories(roostfile.sources)
    lastModificationDate = computeLastModificationDate(sourceFiles)

    // Initial all of our modules from the Roostfile's modules
    for (_, module) in roostfile.modules {
      modules.append(Package.Module(module, parent: self))
    }
  }

  func scanSourcesDirectories(directories: [String]) -> [String] {
    var sources = [String]()

    for sourceDirectory in directories {
      if !(sourceDirectory as NSString).hasSuffix("/") {
        println("Cannot handle directory like '\(sourceDirectory)'")
        continue
      }

      let baseDirectory = roostfile.directory as NSString
      let directory = baseDirectory.stringByAppendingPathComponent(sourceDirectory)

      sources.extend(scanDirectoryForSources(directory))
    }

    return sources
  }

  func computeLastModificationDate(paths: [String]) -> NSDate {
    let manager = NSFileManager.defaultManager()
    
    var dates = [NSDate]()
    var error: NSError?

    for path in paths {
      let attributes = manager.attributesOfItemAtPath(path, error: &error)
      if attributes == nil { continue }

      let maybeDate: AnyObject? = attributes![NSFileModificationDate]
      if maybeDate == nil { continue }

      let date = maybeDate! as! NSDate
      dates.append(date)
    }

    let datesAscending = dates.sorted({ (a: NSDate, b: NSDate) -> Bool in
      return a.compare(b) == NSComparisonResult.OrderedAscending ? true : false
    })
    
    return datesAscending.last!
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
