import Foundation
import Tasker

enum CompilationStatus {
  case Skipped
  case Compiled

  var description: String {
    switch self {
      case .Skipped:  return "Skipped"
      case .Compiled: return "Compiled"
    }
  }
}

struct CompilationResult {
  let status: CompilationStatus
  let roostfile: Roostfile
  let package: Package
}

class CompileOptions {
  var sourceFiles = [String]()
  var includes = [String]()
  var frameworkSearchPaths = [String]()
  var customCompilerOptions = [String]()
  
  // Linker options
  var rpaths = [String]()
  var linkerSearchDirectories = [String]()
  var linkLibraries = [String]()
  var customLinkerOptions = [String]()
}

class Builder {

  var package: Package
  var rootDirectory: String
  var buildDirectory: String
  var binDirectory: String
  var compileOptions = CompileOptions()
  
  var fileManager: NSFileManager     { get { return NSFileManager.defaultManager() } }
  var roostfile: Roostfile           { get { return package.roostfile } }
  var vendorDirectory: String        { get { return package.vendorDirectory } }
  var frameworkSearchPaths: [String] { get { return roostfile.frameworkSearchPaths } }
  var sdkPath: String = ""

  init(_ aPackage: Package) {
    package = aPackage
    rootDirectory = package.directory
    buildDirectory = "\(package.directory)/build"
    binDirectory = "\(package.directory)/bin"
    
    sdkPath = getSDKPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)
  }

  private func commonCompilerArguments() -> [String] {
    return ["swiftc", "-sdk", sdkPath]
  }

  private func commonModuleCompilerArguments() -> [String] {
    var arguments = ["swiftc", "-sdk", sdkPath]

    for rpath in compileOptions.rpaths {
      arguments.extend(["-Xlinker", "-rpath", "-Xlinker", rpath])
    }
    for framework in compileOptions.frameworkSearchPaths {
      arguments.extend(["-F", framework])
    }
    for directory in compileOptions.linkerSearchDirectories {
      arguments.extend(["-L", directory])
    }
    for library in compileOptions.linkLibraries {
      arguments.append("-l\(library)")
    }

    for argument in compileOptions.customCompilerOptions {
      arguments.append(argument)
    }
    for argument in compileOptions.customLinkerOptions {
      arguments.extend(["-Xlinker", argument])
    }

    return arguments
  }

  private func modulePathForPackage() -> String {
    return "\(buildDirectory)/\(roostfile.name).swiftmodule"
  }

  private func checkPreconditions() {
    if package.targetType == .Unknown {
      printAndExit("Can't compile package with Unkown target type")
    }
  }// checkPreconditions

  private func compileDependency(dependency: Roostfile.Dependency, _ directory: String) -> CompilationResult {
    let path = "\(directory)/Roostfile.yaml"
    let contents = readFile(path)

    let dependencyRoostfile = Roostfile()
    dependencyRoostfile.directory = directory
    dependencyRoostfile.parseFromString(contents)

    // Save the Roostfile of the dependency for later
    dependency.roostfile = dependencyRoostfile

    let package = dependencyRoostfile.asPackage()
    let builder = Builder(package)
    let status  = builder.compile()

    return CompilationResult(status: status,
                             roostfile: dependencyRoostfile,
                             package: package)
  }// compileDependency


  private func ensureHaveDependency(dependency: Roostfile.Dependency) -> CompilationResult {
    let directory = dependency.inLocalDirectory(vendorDirectory)

    if !fileManager.fileExistsAtPath(directory) {
      printAndExit("Missing dependency \(dependency.shortName)")
    }

    return compileDependency(dependency, directory)
  }// ensureHaveDependency


  func compile() -> CompilationStatus {
    ensureDirectoryExists(vendorDirectory)
    ensureDirectoryExists(buildDirectory)

    // TODO: Have it return a Bool indicating whether dependencies were
    //       changed to let us know if we need to recompile
    let dependencies = computeDependenciesToBuild()
      .map { return self.ensureHaveDependency($0) }

    checkPreconditions()
    runPrecompileCommands()

    var modulesCompiled = false

    for module in package.modules {
      let compiled = (compileModule(module) == .Compiled)

      modulesCompiled = modulesCompiled || compiled
    }

    var arguments = commonCompilerArguments()

    // Compile all of the sources
    compileOptions.sourceFiles = Array<String>(package.sourceFiles)

    // Add any framework search paths
    for path in frameworkSearchPaths {
      // Compiler framework support
      compileOptions.frameworkSearchPaths.append(path)

      compileOptions.rpaths.append("@executable_path/../\(path)")
    }

    var platformPath = ""
    if package.includeSDKPlatformInRpath || package.includeSDKPlatformInFrameworkPath {
      platformPath = getSDKPlatformPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)

      if package.includeSDKPlatformInRpath {
        compileOptions.rpaths.append("\(platformPath)/Developer/Library/Frameworks")
      }
      if package.includeSDKPlatformInFrameworkPath {
        compileOptions.frameworkSearchPaths.append("\(platformPath)/Developer/Library/Frameworks")
      }
    }


    // If we have built modules to include and link against
    if roostfile.modules.count > 0 {
      // Set search path for the modules
      compileOptions.includes.append("build")
      compileOptions.linkerSearchDirectories.append("build")

      // Link the modules
      for (_, module) in roostfile.modules {
        compileOptions.linkLibraries.append(module.name)
      }
    }

    // Include and link against dependencies
    for result in dependencies {
      let roostfile = result.roostfile
      let package   = result.package
      let directory = roostfile.directory
      let name      = roostfile.name

      let buildPath = "\(directory)/build"
      compileOptions.includes.append(buildPath)
      compileOptions.linkerSearchDirectories.append(buildPath)

      compileOptions.linkLibraries.append(name)

      if let options = hasCustomOptions(roostfile.compilerOptions, forPackage: package) {
        compileOptions.customCompilerOptions.extend(options)
      }
      if let options = hasCustomOptions(roostfile.linkerOptions, forPackage: package) {
        compileOptions.customLinkerOptions.extend(options)
      }
    }

    // Append compiler options if we have any
    if let options = hasCustomOptions(package.compilerOptions, forPackage: package) {
      compileOptions.customCompilerOptions.extend(options)
    }
    if let options = hasCustomOptions(package.linkerOptions, forPackage: package) {
      compileOptions.customLinkerOptions.extend(options)
    }

    switch package.targetType {
      case .Executable:
        ensureDirectoryExists(binDirectory)

        // First check for modification-times of the output executable
        let binFilePath = "\(binDirectory)/\(package.binFileName)"
        let binFileModificationDate = getFileModificationDate(binFilePath)

        // Default to saying it didn't compile; however default to true if
        // there weren't any source files.
        var didCompile = !(compileOptions.sourceFiles.count > 0)

        for source in compileOptions.sourceFiles {
          var needsRecompilation = true
          let missingObjectFile = !fileExists(objectFileForSourceFile(source))

          if let targetDate = binFileModificationDate {
            needsRecompilation = sourceNeedsRecompilation(source,
                                                          targetDate: targetDate)
          } 
          if !missingObjectFile &&
             !needsRecompilation &&
             !Flags.MustRecompile
          {
            continue
          }

          compileSourceToObject(source)
          didCompile = true
        }

        // Link if we compiled objects
        if didCompile {
          var linkerArguments = buildLinkerArguments()
          linkerArguments.extend(["-o", binFilePath])

          announceAndRunTask("Linking \(binFilePath)... ",
                             arguments: linkerArguments,
                             finished: "Linked \(roostfile.name) to \(binFilePath)")
        }


      case .Module:
        let swiftModuleTarget = modulePathForPackage()

        if !modulesCompiled &&
           !needsRecompilation(package.sourceFiles, swiftModuleTarget) &&
           !Flags.MustRecompile
        {
          return .Skipped
        }

        // Do need to recompile
        compileStaticLibrary()
        compileSwiftModule()

      default:
        assert(false, "Target type switch fell through: \(package.targetType)")
    }

    return .Compiled
  }// compile

  private func runPrecompileCommands() {
    let commands = package.roostfile.precompileCommands
    var index = 1

    for command in commands {
      let task = Task("/bin/sh")
      let script = "cd \"\(rootDirectory)\"; \(command)"

      println("Running \(roostfile.name) precompile command #\(index)")

      if Flags.Verbose {
        println(script)
      }

      task.arguments = ["-c", script]
      task.launchAndWait()

      if task.hasAnyOutput() {
        if let output = task.outputData {
          NSFileHandle.fileHandleWithStandardOutput().writeData(output)
        }
        if let error = task.errorData {
          NSFileHandle.fileHandleWithStandardError().writeData(error)
        }
      }
      
      index += 1
    }
  }

  private func compileSwiftModule() {
    var arguments = commonModuleCompilerArguments()
    arguments.extend(compileOptions.sourceFiles)

    let modulePath = modulePathForPackage()

    arguments.extend(["-emit-module-path", modulePath])
    arguments.extend(["-module-name", roostfile.name])

    announceAndRunTask("Compiling \(modulePath)",
                       arguments: arguments,
                       finished: "Created \(roostfile.name) module at \(modulePath)")
  }

  private func compileStaticLibrary() {
    var arguments = commonModuleCompilerArguments()
    arguments.extend(compileOptions.sourceFiles)

    let objectFilePath  = "\(buildDirectory)/tmp-\(roostfile.name).o"
    let libraryFilePath = "\(buildDirectory)/lib\(roostfile.name).a"
    arguments.extend(["-parse-as-library", "-emit-object", "-whole-module-optimization"])
    arguments.extend(["-module-name", roostfile.name])
    arguments.extend(["-o", objectFilePath])

    announceAndRunTask("Compiling \(objectFilePath)... ",
                       arguments: arguments,
                       finished: "Compiled \(roostfile.name) object to \(objectFilePath)")

    let archive = ["libtool", "-o", libraryFilePath, objectFilePath]

    announceAndRunTask("Archiving \(libraryFilePath)... ",
                       arguments: archive,
                       finished: "Created \(roostfile.name) archive at \(libraryFilePath)")
  }


// Compiling modules

  func libraryFilePathForModule(module: Package.Module) -> String {
    return "\(buildDirectory)/lib\(module.name).a"
  }

  func swiftModuleFilePathForModule(module: Package.Module) -> String {
    return "\(buildDirectory)/\(module.name).swiftmodule"
  }

  func compileSwiftModuleForModule(baseArguments: [String], _ module: Package.Module) {
    let path = swiftModuleFilePathForModule(module)
    var arguments = baseArguments

    arguments.extend(["-emit-module-path", path])
    arguments.extend(["-module-name", module.name])

    announceAndRunTask("Compiling \(path)... ",
                       arguments: arguments,
                       finished: "Compiled Swift for module \(module.name) to \(path)")
  }

  func compileNativeModuleForModule(baseArguments: [String], _ module: Package.Module) {
    let temporaryObjectPath = "build/tmp-\(module.name).o"
    let libraryFilePath = libraryFilePathForModule(module)
    var libraryArguments = baseArguments

    libraryArguments.extend(["-parse-as-library", "-emit-object", "-whole-module-optimization"])
    libraryArguments.extend(["-module-name", module.name])
    libraryArguments.extend(["-o", temporaryObjectPath])

    announceAndRunTask("Compiling \(temporaryObjectPath)... ",
                       arguments: libraryArguments,
                       finished: "Compiled object for module \(module.name) to \(temporaryObjectPath)")
    announceAndRunTask("Archiving \(libraryFilePath)... ",
                       arguments: ["libtool", "-o", libraryFilePath, temporaryObjectPath],
                       finished: "Archived library for module \(module.name) to \(libraryFilePath)")

    // Remove the old temporary file
    var error: NSError?
    NSFileManager.defaultManager().removeItemAtPath(temporaryObjectPath, error: &error)
  }

  func compileModule(module: Package.Module) -> CompilationStatus {
    // First check if we even need to compile it
    let libraryPath = libraryFilePathForModule(module)
    let libraryModificationDate = getFileModificationDate(libraryPath)

    if let date = libraryModificationDate {
      if !module.lastModificationDate.isNewerThan(date) {
        return .Skipped
      }
    }

    var arguments = commonModuleCompilerArguments()
    arguments.extend(module.sourceFiles)

    // Compile the Swift module
    compileSwiftModuleForModule(arguments, module)

    // Compile the native library
    compileNativeModuleForModule(arguments, module)

    return .Compiled
  }

// Compilation utilities

  func compileSourceToObject(sourceFile: String) -> String {
    var arguments = ["swiftc", "-frontend", "-c"]

    for s in compileOptions.sourceFiles {
      if s == sourceFile { arguments.append("-primary-file") }
      arguments.append(s)
    }

    arguments.extend(["-target", "x86_64-apple-darwin14.4.0", "-enable-objc-interop"])
    arguments.extend(["-sdk", sdkPath])

    for i in compileOptions.includes {
      arguments.extend(["-I", i])
    }
    for f in compileOptions.frameworkSearchPaths {
      arguments.extend(["-F", f])
    }

    arguments.extend(compileOptions.customCompilerOptions)
    arguments.extend(["-color-diagnostics", "-module-name", "main"])

    let filename = (sourceFile as NSString).lastPathComponent
    let object = objectFileForSourceFile(sourceFile)
    arguments.extend(["-o", object])

    announceAndRunTask("Compiling \(filename)... ",
                       arguments: arguments,
                       finished: "Compiled \(filename)")
    return object
  }


// Utility functions

  func needsRecompilation(sources: [String], _ target: String) -> Bool {
    // First check if we even need to compile it
    let sourcesDate = package.computeLastModificationDate(sources)
    let targetModificationDate = getFileModificationDate(target)

    if let date = targetModificationDate {
      if date.isNewerThan(sourcesDate) {
        return false
      }
    }
    return true
  }

  func sourceNeedsRecompilation(source: String, targetDate: NSDate) -> Bool {
    let sourceDate = getFileModificationDate(source)!

    if sourceDate.isNewerThan(targetDate) {
      return true
    }
    return false
  }

  func objectFileForSourceFile(source: String) -> String {
    let filename = (source as NSString).lastPathComponent
    let hash     = (md5File(source) as NSString).substringToIndex(6)

    return "\(buildDirectory)/\(filename)-\(hash).o"
  }

  func buildLinkerArguments() -> [String] {
    var arguments = ["ld"]

    for source in compileOptions.sourceFiles {
      let filename = (source as NSString).lastPathComponent
      arguments.append("\(self.buildDirectory)/\(filename).o")
    }
    for rpath in compileOptions.rpaths {
      arguments.extend(["-rpath", rpath])
    }
    for framework in compileOptions.frameworkSearchPaths {
      arguments.extend(["-F", framework])
    }
    for directory in compileOptions.linkerSearchDirectories {
      arguments.extend(["-L", directory])
    }
    for library in compileOptions.linkLibraries {
      arguments.append("-l\(library)")
    }

    arguments.extend(compileOptions.customLinkerOptions)
    arguments.extend([
      "-arch", "x86_64",
      "-syslibroot", sdkPath, "-lSystem",
      "-L",     "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx",
      "-rpath", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx",
      "-macosx_version_min", "10.10.0",
      "-no_objc_category_merging",
    ])

    return arguments
  }


// Internal utitlies

  private func readPipeToString(pipe: NSPipe) -> NSString {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return NSString(data: data, encoding: NSUTF8StringEncoding)!
  }

  private func ensureDirectoryExists(path: String) {
    var isDirectory: ObjCBool = false

    let created = fileManager.createDirectoryAtPath(path,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil,
                                                    error: nil)

    if !created {
      printAndExit("Failed to create directory: \(path)")
    }
  }// ensureDirectoryExists

  private func hasCustomOptions(rawOptions: String, forPackage aPackage: Package) -> [String]? {
    let options = rawOptions.stringByTrimmingCharactersInSet(WhitespaceCharacterSet)

    if !isEmpty(options) {
      return (options as NSString)
        .componentsSeparatedByCharactersInSet(WhitespaceCharacterSet)
        .map { $0 as! String }
        .map { self.formatCompilerOption($0, forPackage: aPackage) }
    } else {
      return [String]()
    }
  }

  private func formatCompilerOption(option: String, forPackage aPackage: Package) -> String {
    let root = aPackage.directory

    return option
      .stringByReplacingOccurrencesOfString("{root}", withString: root)
  }

  private func computeDependenciesToBuild() -> [Roostfile.Dependency] {
    return roostfile.dependencies.filter { (dependency: Roostfile.Dependency) -> Bool in
      // Include everything in a test target
      if self.package.forTest { return true }

      if dependency.onlyTest { return false }

      return true
    }
  }

}
