import Foundation

/**
  Manages options to pass to the Swift compiler frontend and generates
  argument arrays to be passed to the compiler.
*/
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

  var buildDirectory: String
  var sourceFiles = [String]() {
    didSet {
      computeSourceToObjectMap()
    }
  }

  var objectFiles: [String] { return Array(sourceToObjectMap.values) }

  init(builder: Builder, buildDirectory: String) {
    self.builder        = builder
    self.buildDirectory = buildDirectory
  }

  func argumentsForFrontend(extraArguments: [String]? = nil) -> [String] {
    var arguments = ["swift", "-frontend", "-c"]

    if let extraArguments = extraArguments {
      arguments.appendContentsOf(extraArguments)
    }

    arguments.appendContentsOf(["-target", builder.platform.targetName, "-enable-objc-interop"])
    arguments.appendContentsOf(["-sdk", getSDKPath()])
    arguments.appendContentsOf(["-F", "\(getSDKPlatformPath())/Developer/Library/Frameworks"])

    for i in includes {
      arguments.appendContentsOf(["-I", i])
    }
    for f in frameworkSearchPaths {
      arguments.appendContentsOf(["-F", f])
    }

    arguments.appendContentsOf(customCompilerOptions)

    let moduleName = builder.roostfile.name
    arguments.appendContentsOf(["-color-diagnostics", "-module-name", moduleName])

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
