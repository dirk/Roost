import Foundation

class CompileOptions {
  // Set by Builder instance that creates this
  var builder: Builder

  var includes = [String]()
  var frameworkSearchPaths = [String]()
  var customCompilerOptions = [String]()
  var sourceToObjectMap = [String : String]()

  // Linker options
  var rpaths = [String]()
  var linkerSearchDirectories = [String]()
  var linkLibraries = [String]()
  var customLinkerOptions = [String]()

  var sourceFiles = [String]() {
    didSet {
      computeSourceToObjectMap()
    }
  }

  var objectFiles: [String]  { return Array(sourceToObjectMap.values) }
  var buildDirectory: String { return builder.buildDirectory }

  init(builder: Builder) {
    self.builder = builder
  }

  func argumentsForFrontend(extraArguments: [String]? = nil) -> [String] {
    var arguments = ["swiftc", "-frontend", "-c"]

    if let extraArguments = extraArguments {
      arguments.appendContentsOf(extraArguments)
    }

    arguments.appendContentsOf(["-target", "x86_64-apple-darwin14.4.0", "-enable-objc-interop"])
    arguments.appendContentsOf(["-sdk", getSDKPath()])
    arguments.appendContentsOf(["-F", "\(getSDKPlatformPath())/Developer/Library/Frameworks"])

    for i in includes {
      arguments.appendContentsOf(["-I", i])
    }
    for f in frameworkSearchPaths {
      arguments.appendContentsOf(["-F", f])
    }

    arguments.appendContentsOf(customCompilerOptions)
    arguments.appendContentsOf(["-color-diagnostics", "-module-name", "main"])

    return arguments
  }

  func objectFileForSourceFile(source: String) -> String {
    if let object = sourceToObjectMap[source] {
      return object
    } else {
      printAndExit("Object file not found for source file: \(source)")
      return ""
    }
  }


  private func computeSourceToObjectMap() {
    var map = [String : String]()

    for source in sourceFiles {
      let object = computeObjectFileForSourceFile(source)
      map[source] = object
    }

    sourceToObjectMap = map
  }

  private func computeObjectFileForSourceFile(path: String) -> String {
    let filename = (path as NSString).lastPathComponent
    let hash     = (path.computeMD5() as NSString).substringToIndex(6)

    return "\(buildDirectory)/\(filename)-\(hash).o"
  }

}
