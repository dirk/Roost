import Foundation
import Tasker

extension Package {

  var frameworkSearchPaths: [String] {
    get { return roostfile.frameworkSearchPaths }
  }

  private func commonCompilerArguments() -> [String] {
    let sdkPath = getSDKPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)

    return ["swiftc", "-sdk", sdkPath]
  }

  func compile() {
    var modulesCompiled = false

    for module in modules {
      let compiled = compileModule(module)

      modulesCompiled = modulesCompiled || compiled
    }

    let binFilePath = "bin/\(roostfile.name.lowercaseString)"
    let binFileModificationDate = getFileModificationDate(binFilePath)

    if let date = binFileModificationDate {
      // Don't bother compiling if we haven't been modified since the last
      // target was built
      if !modulesCompiled && !lastModificationDate.isNewerThan(date) {
        return
      }
    }

    var arguments = commonCompilerArguments()

    // Compile all of the sources
    arguments.extend(sourceFiles)

    // And set the location of the output executable
    arguments.append("-o")
    arguments.append(binFilePath)

    // Add any framework search paths
    for path in frameworkSearchPaths {
      arguments.append("-F \(path)")
    }

    // Set search path for the modules
    arguments.append("-I build")
    arguments.append("-L build")

    // Link the modules
    for (_, module) in roostfile.modules {
      arguments.append("-l\(module.name)")
    }

    announceAndRunTask("Compiling \(binFilePath)... ",
                       arguments: ["-c", " ".join(arguments)],
                       finished: "Compiled \(roostfile.name) to \(binFilePath)")
  }


// Compiling modules

  func libraryFilePathForModule(module: Package.Module) -> String {
    return "build/lib\(module.name).a"
  }

  func swiftModuleFilePathForModule(module: Package.Module) -> String {
    return "build/\(module.name).swiftmodule"
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

  func compileModule(module: Package.Module) -> Bool {
    // First check if we even need to compile it
    let libraryPath = libraryFilePathForModule(module)
    let libraryModificationDate = getFileModificationDate(libraryPath)

    if let date = libraryModificationDate {
      if !module.lastModificationDate.isNewerThan(date) {
        return false
      }
    }

    var arguments = commonCompilerArguments()
    arguments.extend(module.sourceFiles)

    // Compile the Swift module
    compileSwiftModuleForModule(arguments, module)

    // Compile the native library
    compileNativeModuleForModule(arguments, module)

    return true
  }


// Internal utitlies

  func announceAndRunTask(announcement: String, arguments: [String], finished: String) {
    print(announcement)
    stdoutFlush()

    let task = Task("/bin/sh")
    task.arguments = arguments

    task.launchAndWait()

    print("\r") // Reset to beginning of line

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
