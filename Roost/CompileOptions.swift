import Foundation

class CompileOptions {
  var sdkPath: String!
  var sourceFiles = [String]()
  var includes = [String]()
  var frameworkSearchPaths = [String]()
  var customCompilerOptions = [String]()

  // Linker options
  var rpaths = [String]()
  var linkerSearchDirectories = [String]()
  var linkLibraries = [String]()
  var customLinkerOptions = [String]()

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
}
