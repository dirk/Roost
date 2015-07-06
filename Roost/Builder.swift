import Foundation
import Tasker

enum CompilationResult {
  case Skipped
  case Compiled

  var description: String {
    switch self {
      case .Skipped:  return "Skipped"
      case .Compiled: return "Compiled"
    }
  }
}

class Builder {

  var package: Package
  var buildDirectory: String!

  var fileManager: NSFileManager     { get { return NSFileManager.defaultManager() } }

  var roostfile: Roostfile           { get { return package.roostfile } }
  var frameworkSearchPaths: [String] { get { return roostfile.frameworkSearchPaths } }
  var vendorDirectory: String        { get { return "\(roostfile.directory)/vendor" } }

  init(_ aPackage: Package) {
    package = aPackage
    buildDirectory = "\(package.directory)/build"
  }

  private func commonCompilerArguments() -> [String] {
    let sdkPath = getSDKPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)

    return ["swiftc", "-sdk", sdkPath]
  }

  private func modulePathForPackage() -> String {
    return "\(buildDirectory)/\(roostfile.name).swiftmodule"
  }

  private func checkPreconditions() {
    if package.targetType == .Unknown {
      printAndExit("Can't compile package with Unkown target type")
    }
  }// checkPreconditions

  private func ensureHaveDependencies() {
    if !fileManager.fileExistsAtPath(vendorDirectory) {
      let created = fileManager.createDirectoryAtPath(vendorDirectory,
                                                      withIntermediateDirectories: true,
                                                      attributes: nil,
                                                      error: nil)

      if !created {
        printAndExit("Failed to create vendor directory: \(vendorDirectory)")
      }
    }

    for dependency in roostfile.dependencies {
      ensureHaveDependency(dependency)
    }
  }// ensureHaveDependencies

  private func cloneDependency(dependency: Roostfile.Dependency, _ directory: String) {
    let sourceURL = dependency.sourceURL()
    let cloneCommand = "git clone -q \(sourceURL) \(directory)"

    announceAndRunTask("Cloning dependency \(dependency.shortName)... ",
                       arguments: ["-c", cloneCommand],
                       finished: "Cloned dependency \(dependency.shortName)")
  }

  private func pullDependency(dependency: Roostfile.Dependency, _ directory: String) {
    let commandsArray = [
      "cd \(directory)",
      "git pull -q origin master",
    ]
    let commands = " && ".join(commandsArray)

    announceAndRunTask("Pulling dependency \(dependency.shortName)... ",
                       arguments: ["-c", commands],
                       finished: "Pulled dependency \(dependency.shortName)")
  }// pullDependency

  private func compileDependency(dependency: Roostfile.Dependency, _ directory: String) -> CompilationResult {
    let path = "\(directory)/Roostfile.yaml"
    let contents = readFile(path)

    let dependencyRoostfile = Roostfile()
    dependencyRoostfile.directory = directory
    dependencyRoostfile.parseFromString(contents)

    // Save the Roostfile of the dependency for later
    dependency.roostfile = dependencyRoostfile

    let dependencyPackage = dependencyRoostfile.asPackage()
    let dependencyBuilder = Builder(dependencyPackage)

    return dependencyBuilder.compile()
  }// compileDependency


  private func ensureHaveDependency(dependency: Roostfile.Dependency) {
    let directory = "\(vendorDirectory)/\(dependency.localDirectoryName())"

    if !fileManager.fileExistsAtPath(directory) {
      cloneDependency(dependency, directory)
    } else {
      // TODO: Add flag to enable pulling and such
      // pullDependency(dependency, directory)
    }

    compileDependency(dependency, directory)
  }// ensureHaveDependency


  func compile() -> CompilationResult {
    // TODO: Have it return a Bool indicating whether dependencies were
    //       changed to let us know if we need to recompile
    ensureHaveDependencies()

    checkPreconditions()

    var modulesCompiled = false

    for module in package.modules {
      let compiled = (compileModule(module) == .Compiled)

      modulesCompiled = modulesCompiled || compiled
    }

    var arguments = commonCompilerArguments()

    // Compile all of the sources
    arguments.extend(package.sourceFiles)

    // Add any framework search paths
    for path in frameworkSearchPaths {
      // Compiler framework support
      arguments.append("-F \(path)")

      // Linker framework support
      arguments.append("-Xlinker -rpath -Xlinker @executable_path/../\(path)")
    }

    // If we have built modules to include and link against
    if roostfile.modules.count > 0 {
      // Set search path for the modules
      arguments.append("-I build")
      arguments.append("-L build")

      // Link the modules
      for (_, module) in roostfile.modules {
        arguments.append("-l\(module.name)")
      }
    }

    // Include and link against dependencies
    if roostfile.dependencies.count > 0 {
      for dep in roostfile.dependencies {
        let directory = dep.roostfile!.directory
        let name = dep.moduleName

        let buildPath = "\(directory)/build"
        arguments.append("-I \(buildPath) -L \(buildPath)")

        // Link the dependency's module
        arguments.append("-l\(name)")
      }
    }

    switch package.targetType {
      case .Executable:
        // First check for modification-times of the output executable
        let binFilePath = "bin/\(roostfile.name.lowercaseString)"
        let binFileModificationDate = getFileModificationDate(binFilePath)

        if let date = binFileModificationDate {
          let targetNewer = date.isNewerThan(package.lastModificationDate)
          // Don't bother compiling if we haven't been modified since the last
          // target was built
          if !modulesCompiled && targetNewer && !Flags.MustRecompile {
            return .Skipped
          }
        }

        // And set the location of the output executable
        arguments.append("-o")
        arguments.append(binFilePath)

        announceAndRunTask("Compiling \(binFilePath)... ",
                           arguments: ["-c", " ".join(arguments)],
                           finished: "Compiled \(roostfile.name) to \(binFilePath)")

      case .Module:
        let swiftModuleTarget = modulePathForPackage()

        if !modulesCompiled &&
           !needsRecompilation(package.sourceFiles, swiftModuleTarget) &&
           !Flags.MustRecompile
        {
          return .Skipped
        }
        // Do need to recompile
        compileStaticLibrary(arguments)
        compileSwiftModule(arguments)

      default:
        assert(false, "Target type switch fell through: \(package.targetType)")
    }

    return .Compiled
  }// compile

  private func compileSwiftModule(baseArguments: [String]) {
    var arguments = baseArguments

    let modulePath = modulePathForPackage()

    arguments.append("-emit-module-path \(modulePath)")

    announceAndRunTask("Compiling \(modulePath)",
                       arguments: ["-c", " ".join(arguments)],
                       finished: "Created \(roostfile.name) module at \(modulePath)")
  }

  private func compileStaticLibrary(baseArguments: [String]) {
    var arguments = baseArguments

    let objectFilePath  = "\(buildDirectory)/tmp-\(roostfile.name).o"
    let libraryFilePath = "\(buildDirectory)/lib\(roostfile.name).a"
    arguments.append("-parse-as-library -emit-object")
    arguments.append("-module-name \(roostfile.name)")
    arguments.append("-o \(objectFilePath)")

    announceAndRunTask("Compiling \(objectFilePath)... ",
                       arguments: ["-c", " ".join(arguments)],
                       finished: "Compiled \(roostfile.name) object to \(objectFilePath)")

    let archive = "libtool -o \(libraryFilePath) \(objectFilePath)"

    announceAndRunTask("Archiving \(libraryFilePath)... ",
                       arguments: ["-c", archive],
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
    announceAndRunTask("Compiling \(path)... ",
                       arguments: ["-c", " ".join(arguments)],
                       finished: "Compiled Swift for module \(module.name) to \(path)")
  }

  func compileNativeModuleForModule(baseArguments: [String], _ module: Package.Module) {
    let temporaryObjectPath = "build/tmp-\(module.name).o"
    let libraryFilePath = libraryFilePathForModule(module)
    var libraryArguments = baseArguments

    libraryArguments.extend(["-parse-as-library", "-emit-object"])
    libraryArguments.extend(["-module-name", module.name])
    libraryArguments.extend(["-o", temporaryObjectPath])
    announceAndRunTask("Compiling \(temporaryObjectPath)... ",
                       arguments: ["-c", " ".join(libraryArguments)],
                       finished: "Compiled object for module \(module.name) to \(temporaryObjectPath)")
    announceAndRunTask("Archiving \(libraryFilePath)... ",
                       arguments: ["-c", "libtool -o \(libraryFilePath) \(temporaryObjectPath)"],
                       finished: "Archived library for module \(module.name) to \(libraryFilePath)")

    // Remove the old temporary file
    var error: NSError?
    NSFileManager.defaultManager().removeItemAtPath(temporaryObjectPath, error: &error)
  }

  func compileModule(module: Package.Module) -> CompilationResult {
    // First check if we even need to compile it
    let libraryPath = libraryFilePathForModule(module)
    let libraryModificationDate = getFileModificationDate(libraryPath)

    if let date = libraryModificationDate {
      if !module.lastModificationDate.isNewerThan(date) {
        return .Skipped
      }
    }

    var arguments = commonCompilerArguments()
    arguments.extend(module.sourceFiles)

    // Compile the Swift module
    compileSwiftModuleForModule(arguments, module)

    // Compile the native library
    compileNativeModuleForModule(arguments, module)

    return .Compiled
  }

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

// Internal utitlies

  func announceAndRunTask(announcement: String, arguments: [String], finished: String) {
    print(announcement)
    stdoutFlush()

    let task = Task("/bin/sh")
    task.arguments = arguments

    task.launchAndWait()

    print("\u{001B}[2K") // Clear the whole line
    print("\r") // Reset cursor to the beginning of line

    if task.hasAnyOutput() {
      println(task.outputString)
      println(task.errorString)
    } else {
      println(finished)
    }
  }

  private func stdoutFlush() {
    fflush(__stdoutp)
  }

  private func readPipeToString(pipe: NSPipe) -> NSString {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return NSString(data: data, encoding: NSUTF8StringEncoding)!
  }

}
