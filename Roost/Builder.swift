import Foundation
import Tasker

enum CompilationStatus {
  case Skipped
  case Compiled
  case Failed

  var description: String {
    switch self {
      case .Skipped:  return "Skipped"
      case .Compiled: return "Compiled"
      case .Failed:   return "Failed"
    }
  }
}

struct CompilationResult {
  let status: CompilationStatus
  let roostfile: Roostfile
  let package: Package
}

class Builder {

  var package: Package
  var rootDirectory: String
  var buildDirectory: String
  var binDirectory: String
  var compileOptions: CompileOptions!

  var fileManager: NSFileManager     { return NSFileManager.defaultManager() }
  var roostfile: Roostfile           { return package.roostfile }
  var vendorDirectory: String        { return package.vendorDirectory }
  var frameworkSearchPaths: [String] { return roostfile.frameworkSearchPaths }

  init(_ aPackage: Package) {
    package = aPackage
    rootDirectory = package.directory
    buildDirectory = "\(package.directory)/build"
    binDirectory = "\(package.directory)/bin"

    compileOptions  = CompileOptions(builder: self)
  }

  private func commonCompilerArguments() -> [String] {
    return ["swiftc", "-sdk", getSDKPath()]
  }

  private func commonModuleCompilerArguments() -> [String] {
    var arguments = [
      "swiftc",
      "-sdk", getSDKPath(),
      "-F", "\(getSDKPlatformPath())/Developer/Library/Frameworks",
    ]

    for rpath in compileOptions.rpaths {
      arguments.appendContentsOf(["-Xlinker", "-rpath", "-Xlinker", rpath])
    }
    for framework in compileOptions.frameworkSearchPaths {
      arguments.appendContentsOf(["-F", framework])
    }
    for directory in compileOptions.linkerSearchDirectories {
      arguments.appendContentsOf(["-L", directory])
    }
    for library in compileOptions.linkLibraries {
      arguments.append("-l\(library)")
    }

    for argument in compileOptions.customCompilerOptions {
      arguments.append(argument)
    }
    for argument in compileOptions.customLinkerOptions {
      arguments.appendContentsOf(["-Xlinker", argument])
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

  private func compileSource(source: String, ifNewerThan: NSDate?) -> CompilationStatus {
    var sourceNewerThanTarget = true
    let missingObjectFile     = !fileExists(compileOptions.objectFileForSourceFile(source))

    if let targetDate = ifNewerThan, sourceDate = getFileModificationDate(source) {
      sourceNewerThanTarget = sourceDate.isNewerThan(targetDate)
    }

    if !missingObjectFile &&
       !sourceNewerThanTarget &&
       !Flags.MustRecompile
    {
      return .Skipped
    }

    let otherSourceFiles = compileOptions.sourceFiles.filter({ $0 != source })
    let object = compileOptions.objectFileForSourceFile(source)

    let compileable = CompileableObject(compileOptions: compileOptions,
                                        primarySourceFile: source,
                                        otherSourceFiles: otherSourceFiles,
                                        targetObjectFile: object)

    let exitStatus = compileable.compile()

    if exitStatus != 0 {
      let filename = (source as NSString).lastPathComponent
      print("Compilation of \(filename) failed with status \(exitStatus)")
      return .Failed
    }

    return .Compiled
  }


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
        compileOptions.customCompilerOptions.appendContentsOf(options)
      }
      if let options = hasCustomOptions(roostfile.linkerOptions, forPackage: package) {
        compileOptions.customLinkerOptions.appendContentsOf(options)
      }
    }

    // Append compiler options if we have any
    if let options = hasCustomOptions(package.compilerOptions, forPackage: package) {
      compileOptions.customCompilerOptions.appendContentsOf(options)
    }
    if let options = hasCustomOptions(package.linkerOptions, forPackage: package) {
      compileOptions.customLinkerOptions.appendContentsOf(options)
    }

    switch package.targetType {
      case .Executable:
        ensureDirectoryExists(binDirectory)

        // First check for modification-times of the output executable
        let binFilePath = "\(binDirectory)/\(package.binFileName)"
        let binFileModificationDate = getFileModificationDate(binFilePath)

        let statuses = compileOptions.sourceFiles.map({
          self.compileSource($0, ifNewerThan: binFileModificationDate)
        })

        // Stop if any failed or all were skipped.
        if statuses.filter({ $0 == .Failed }).count > 0   { return .Failed  }
        if statuses.filter({ $0 != .Skipped }).count == 0 { return .Skipped }

        var linkerArguments = buildLinkerArguments()
        linkerArguments.appendContentsOf(["-o", binFilePath])

        announceAndRunTask("Linking \(binFilePath)... ",
                           arguments: linkerArguments,
                           finished: "Linked \(roostfile.name) to \(binFilePath)")

      case .Module:
        let swiftModuleTarget = modulePathForPackage()
        let swiftModuleModificationDate = getFileModificationDate(swiftModuleTarget)

        let statuses = compileOptions.sourceFiles.map({
          self.compileSource($0, ifNewerThan: swiftModuleModificationDate)
        })

        // Stop if any failed or all were skipped.
        if statuses.filter({ $0 == .Failed }).count > 0   { return .Failed  }
        if statuses.filter({ $0 != .Skipped }).count == 0 { return .Skipped }

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

      print("Running \(roostfile.name) precompile command #\(index)")

      if Flags.Verbose {
        print(script)
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
    arguments.appendContentsOf(compileOptions.sourceFiles)

    let modulePath = modulePathForPackage()

    arguments.appendContentsOf(["-emit-module-path", modulePath])
    arguments.appendContentsOf(["-module-name", roostfile.name])

    announceAndRunTask("Compiling \(modulePath)",
                       arguments: arguments,
                       finished: "Created \(roostfile.name) module at \(modulePath)")
  }

  private func compileStaticLibrary() {
    let libraryFilePath = "\(buildDirectory)/lib\(roostfile.name).a"

    var libtoolArguments = ["libtool", "-o", libraryFilePath]
    libtoolArguments.appendContentsOf(compileOptions.objectFiles)

    announceAndRunTask("Archiving \(libraryFilePath)... ",
                       arguments: libtoolArguments,
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

    arguments.appendContentsOf(["-emit-module-path", path])
    arguments.appendContentsOf(["-module-name", module.name])

    announceAndRunTask("Compiling \(path)... ",
                       arguments: arguments,
                       finished: "Compiled Swift for module \(module.name) to \(path)")
  }

  func compileNativeModuleForModule(baseArguments: [String], _ module: Package.Module) {
    let temporaryObjectPath = "build/tmp-\(module.name).o"
    let libraryFilePath = libraryFilePathForModule(module)
    var libraryArguments = baseArguments

    libraryArguments.appendContentsOf(["-parse-as-library", "-emit-object", "-whole-module-optimization"])
    libraryArguments.appendContentsOf(["-module-name", module.name])
    libraryArguments.appendContentsOf(["-o", temporaryObjectPath])

    announceAndRunTask("Compiling \(temporaryObjectPath)... ",
                       arguments: libraryArguments,
                       finished: "Compiled object for module \(module.name) to \(temporaryObjectPath)")
    announceAndRunTask("Archiving \(libraryFilePath)... ",
                       arguments: ["libtool", "-o", libraryFilePath, temporaryObjectPath],
                       finished: "Archived library for module \(module.name) to \(libraryFilePath)")

    // Remove the old temporary file
    _ = try? NSFileManager.defaultManager().removeItemAtPath(temporaryObjectPath)
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
    arguments.appendContentsOf(module.sourceFiles)

    // Compile the Swift module
    compileSwiftModuleForModule(arguments, module)

    // Compile the native library
    compileNativeModuleForModule(arguments, module)

    return .Compiled
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

  func buildLinkerArguments() -> [String] {
    var arguments = ["ld"]

    for object in compileOptions.objectFiles {
      arguments.append(object)
    }
    for rpath in compileOptions.rpaths {
      arguments.appendContentsOf(["-rpath", rpath])
    }
    for framework in compileOptions.frameworkSearchPaths {
      arguments.appendContentsOf(["-F", framework])
    }
    for directory in compileOptions.linkerSearchDirectories {
      arguments.appendContentsOf(["-L", directory])
    }
    for library in compileOptions.linkLibraries {
      arguments.append("-l\(library)")
    }

    arguments.appendContentsOf(compileOptions.customLinkerOptions)
    arguments.appendContentsOf([
      "-arch", "x86_64",
      "-syslibroot", getSDKPath(), "-lSystem",
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
    do {
      try fileManager.createDirectoryAtPath(path,
                                            withIntermediateDirectories: true,
                                            attributes: nil)

    } catch {
      printAndExit("Failed to create directory: \(path)")
    }
  }// ensureDirectoryExists

  private func hasCustomOptions(rawOptions: String, forPackage aPackage: Package) -> [String]? {
    let options = rawOptions.stringByTrimmingCharactersInSet(WhitespaceCharacterSet)

    if !options.characters.isEmpty {
      return (options as NSString)
        .componentsSeparatedByCharactersInSet(WhitespaceCharacterSet)
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
