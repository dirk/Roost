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

  private func checkPreconditions() {
    if targetType == .Unknown {
      println("Can't compile package with Unkown target type")
      exit(2)
    }
  }

  func compile() {
    checkPreconditions()

    var modulesCompiled = false

    for module in modules {
      let compiled = compileModule(module)

      modulesCompiled = modulesCompiled || compiled
    }

    var arguments = commonCompilerArguments()

    // Compile all of the sources
    arguments.extend(sourceFiles)

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

    switch targetType {
      case .Executable:
        // First check for modification-times of the output executable
        let binFilePath = "bin/\(roostfile.name.lowercaseString)"
        let binFileModificationDate = getFileModificationDate(binFilePath)
        if let date = binFileModificationDate {
          // Don't bother compiling if we haven't been modified since the last
          // target was built
          if !modulesCompiled && !lastModificationDate.isNewerThan(date) {
            return
          }
        }

        // And set the location of the output executable
        arguments.append("-o")
        arguments.append(binFilePath)

        announceAndRunTask("Compiling \(binFilePath)... ",
                           arguments: ["-c", " ".join(arguments)],
                           finished: "Compiled \(roostfile.name) to \(binFilePath)")

      case .Module:
        compileStaticLibrary(arguments)
        compileSwiftModule(arguments)

      default:
        assert(false, "Target type switch fell through: \(targetType)")
    }
  }

  private func compileSwiftModule(baseArguments: [String]) {
    var arguments = baseArguments

    let modulePath = "build/\(roostfile.name).swiftmodule"

    arguments.append("-emit-module-path \(modulePath)")

    announceAndRunTask("Compiling \(modulePath)",
                       arguments: ["-c", " ".join(arguments)],
                       finished: "Created \(roostfile.name) module at \(modulePath)")
  }

  private func compileStaticLibrary(baseArguments: [String]) {
    var arguments = baseArguments

    let objectFilePath  = "build/tmp-\(roostfile.name).o"
    let libraryFilePath = "build/lib\(roostfile.name).a"
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
