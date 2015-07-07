import Foundation

class Package {
  var roostfile: Roostfile
    
  var directory: String
  var sourceFiles: [String] = []
  var lastModificationDate: NSDate = NSDate()
  var modules: [Package.Module] = []

  var targetType: TargetType {
    get { return roostfile.targetType }
  }
  var vendorDirectory: String {
    get { return "\(directory)/vendor" }
  }

  init(_ r: Roostfile) {
    roostfile = r
    directory = roostfile.directory

    let (directories, files, nonMatching) = filterSources(roostfile.sources)

    if nonMatching.count > 0 {
      let items = ", ".join(nonMatching)
      printAndExit("Failed to parse as file or directory: \(items)")
    }

    sourceFiles          = scanSourcesDirectories(directories) + files
    lastModificationDate = computeLastModificationDate(sourceFiles)

    // Initial all of our modules from the Roostfile's modules
    for (_, module) in roostfile.modules {
      modules.append(Package.Module(module, parent: self))
    }
  }

  /**
    Given a list of source files and/or directories, determine the set
    of usable directories, files, and invalid paths.

    :param: sources Files and directories

    :returns: Three-tuple of directories, source files, and non-matching.
  */
  func filterSources(sources: [String]) -> ([String], [String], [String]) {
    var directories = [String]()
    var files       = [String]()
    var nonMatching = [String]()

    for sourceString in sources {
      let source = sourceString as NSString

      if source.hasSuffix("/") {
        directories.append(source as String)
      
      } else if source.hasSuffix(".swift") {
        let expandedPath = "\(directory)/\(source)"
        files.append(expandedPath)
      
      } else {
        nonMatching.append(source as String)
      }
    }

    return (directories, files, nonMatching)
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

      if attributes == nil {
        println("Failed to lookup attributes for file: \(path)")
        println(error)
        exit(1)
      }

      let maybeDate: AnyObject? = attributes![NSFileModificationDate]

      if maybeDate == nil {
        printAndExit("Modification date not found for file: \(path)")
      }

      let date = maybeDate! as! NSDate
      dates.append(date)
    }

    let datesAscending = dates.sorted({ (a: NSDate, b: NSDate) -> Bool in
      return !a.isNewerThan(b)
      // return a.compare(b) == NSComparisonResult.OrderedAscending ? true : false
    })
    
    return datesAscending.last!
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
