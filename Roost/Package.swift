import Foundation

class Package {
  var roostfile: Roostfile

  var sourceFiles: [String] = []
  var lastModificationDate: NSDate = NSDate()
  var modules: [Package.Module] = []

  var binFileName: String!
  var compilerOptions: String
  var linkerOptions: String
  var forTest: Bool = false
  var includeSDKPlatformInRpath: Bool = false
  var includeSDKPlatformInFrameworkPath: Bool = false

  var targetType: TargetType {
    get { return roostfile.targetType }
  }
  var directory: String {
    get { return roostfile.directory }
  }
  var vendorDirectory: String {
    get { return "\(directory)/vendor" }
  }

  init(_ r: Roostfile) {
    roostfile       = r
    compilerOptions = roostfile.compilerOptions
    linkerOptions   = roostfile.linkerOptions

    sourceFiles          = scanSources(roostfile.sources)
    lastModificationDate = computeLastModificationDate(sourceFiles)

    // Initialize all of our modules from the Roostfile's modules
    for (_, module) in roostfile.modules {
      modules.append(Package.Module(module, parent: self))
    }

    if targetType == .Executable {
      binFileName = roostfile.name.lowercaseString
    }
  }

  init(testSources: [String], forRoostfile r: Roostfile) {
    roostfile       = r
    compilerOptions = "\(roostfile.compilerOptions) \(roostfile.testCompilerOptions)"
    linkerOptions   = "\(roostfile.linkerOptions) \(roostfile.testCompilerOptions)"

    let primaryFiles = scanSources(roostfile.sources).filter {
      return !$0.contains("main.swift")
    }
    let testFiles    = scanSources(testSources)

    sourceFiles          = primaryFiles + testFiles
    lastModificationDate = NSDate()

    // Testing-specific configuration for Builder
    binFileName                       = "test-\(roostfile.name.lowercaseString)"
    forTest                           = true
    includeSDKPlatformInRpath         = true
    includeSDKPlatformInFrameworkPath = true
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

  func scanSources(sources: [String]) -> [String] {
    let (directories, files, nonMatching) = filterSources(sources)

    if nonMatching.count > 0 {
      let items = nonMatching.joinWithSeparator(", ")
      printAndExit("Failed to parse as file or directory: \(items)")
    }

    return scanSourcesDirectories(directories) + files
  }

  func scanSourcesDirectories(directories: [String]) -> [String] {
    var sources = [String]()

    for sourceDirectory in directories {
      if !(sourceDirectory as NSString).hasSuffix("/") {
        printAndExit("Cannot handle directory like '\(sourceDirectory)'")
      }

      let baseDirectory = roostfile.directory as NSString
      let directory = baseDirectory.stringByAppendingPathComponent(sourceDirectory)

      sources.appendContentsOf(scanDirectoryForSources(directory))
    }

    return sources
  }

  func computeLastModificationDate(paths: [String]) -> NSDate {
    let manager = NSFileManager.defaultManager()

    var dates = [NSDate]()

    for path in paths {
      var attributes: [String : AnyObject]

      do {
        attributes = try manager.attributesOfItemAtPath(path)
      } catch {
        print("Failed to lookup attributes for file: \(path)")
        print(error)
        exit(1)
      }

      let maybeDate: AnyObject? = attributes[NSFileModificationDate]

      if maybeDate == nil {
        printAndExit("Modification date not found for file: \(path)")
      }

      let date = maybeDate! as! NSDate
      dates.append(date)
    }

    let datesAscending = dates.sort({ (a: NSDate, b: NSDate) -> Bool in
      return !a.isNewerThan(b)
      // return a.compare(b) == NSComparisonResult.OrderedAscending ? true : false
    })

    return datesAscending.last!
  }

  func scanDirectoryForSources(directory: String) -> [String] {
    let fileManager = NSFileManager()

    if let enumerator = fileManager.enumeratorAtPath(directory) {
      var files = [String]()

      for file in enumerator {
        if !file.hasSuffix(".swift") { continue }

        let fileURL = NSURL(fileURLWithPath: directory).URLByAppendingPathComponent(file as! String)

        files.append(fileURL.path!)
      }

      return files

    } else {
      printAndExit("Failed to enumerate files in directory: \(directory)")
      return []
    }
  }// scanSources()

}
