import Foundation
import Tasker

extension Package {

  private func commonCompilerArguments() -> [String] {
    let sdkPath = getSDKPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)

    return ["swiftc", "-sdk", sdkPath]
  }

  func libraryFilePathForModule(module: Roostfile.Module) -> String {
    return "build/lib\(module.name).dylib"
  }

  func compileModule(module: Roostfile.Module) {
    let moduleFilePath = "build/\(module.name).swiftmodule"
    let libraryFilePath = libraryFilePathForModule(module)

    var arguments = commonCompilerArguments()

    var sources = [String]()

    for sourceDirectory in module.sources {
      let directory = (roostfile.directory as NSString).stringByAppendingPathComponent(sourceDirectory)

      sources.extend(scanDirectoryForSources(directory))
    }

    arguments.extend(sources)

    // Compile the Swift module
    var moduleArguments = arguments

    moduleArguments.extend(["-emit-module-path", moduleFilePath])
    announceAndRunTask("Compiling \(moduleFilePath)... ",
                       arguments: ["-c", " ".join(moduleArguments)],
                       finished: "Compiled Swift for module \(module.name) to \(moduleFilePath)")

    // Compile the Swift library
    var libraryArguments = arguments

    libraryArguments.extend(["-emit-library -o", libraryFilePath])
    executeShellTaskWithArguments(libraryArguments)

    announceAndRunTask("Compiling \(libraryFilePath)... ",
                       arguments: ["-c", " ".join(libraryArguments)],
                       finished: "Compiled library for module \(module.name) to \(libraryFilePath)")
  }

  func compile() {
    for (_, module) in roostfile.modules {
      compileModule(module)
    }

    let binFilePath = "bin/\(roostfile.name.lowercaseString)"

    var arguments = commonCompilerArguments()

    // Compile all of the sources
    arguments.extend(sourceFiles)

    // And set the location of the output executable
    arguments.append("-o")
    arguments.append(binFilePath)

    // Set search path
    arguments.append("-I build")
    arguments.append("-L build")

    for (_, module) in roostfile.modules {
      arguments.append("-l\(module.name)")
    }

    announceAndRunTask("Compiling \(binFilePath)... ",
                       arguments: ["-c", " ".join(arguments)],
                       finished: "Compiled \(roostfile.name) to \(binFilePath)")
  }

  func announceAndRunTask(announcement: String, arguments: [String], finished: String) {
    print(announcement)
    fflush(__stdoutp)

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

  func executeShellTaskWithArguments(arguments: [String]) -> NSTask {
    let argumentsString = " ".join(arguments)
    let outputPipe = NSPipe()
    let errorPipe  = NSPipe()
    let task = NSTask()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", argumentsString]
    task.standardOutput = outputPipe
    task.standardError  = errorPipe

    task.launch()

    print(readPipeToString(outputPipe))
    print(readPipeToString(errorPipe))

    return task
  }

  private func readPipeToString(pipe: NSPipe) -> NSString {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return NSString(data: data, encoding: NSUTF8StringEncoding)!
  }

}
