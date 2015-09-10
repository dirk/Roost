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

  var sourceFiles: [String] {
    get {
      return _sourceFiles
    }
    set {
      _sourceFiles = newValue
      computeSourceToObjectMap()
    }
  }
  var objectFiles: [String] {
    get { return sourceToObjectMap.values.array }
  }
  var sdkPath: String {
    get { return builder.sdkPath }
  }
  var buildDirectory: String {
    get { return builder.buildDirectory }
  }

  // Internal storage for `sourceFiles` computed property.
  private var _sourceFiles = [String]()


  init(builder: Builder) {
    self.builder = builder
  }

  func argumentsForFrontend(_ extraArguments: [String]? = nil) -> [String] {
    var arguments = ["swiftc", "-frontend", "-c"]

    if let extraArguments = extraArguments {
      arguments.extend(extraArguments)
    }

    arguments.extend(["-target", "x86_64-apple-darwin14.4.0", "-enable-objc-interop"])
    arguments.extend(["-sdk", sdkPath])

    for i in includes {
      arguments.extend(["-I", i])
    }
    for f in frameworkSearchPaths {
      arguments.extend(["-F", f])
    }

    arguments.extend(customCompilerOptions)
    arguments.extend(["-color-diagnostics", "-module-name", "main"])

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
