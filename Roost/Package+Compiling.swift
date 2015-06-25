import Foundation

extension Package {

  private func commonCompilerArguments() -> [String] {
    let sdkPath = getSDKPath().stringByTrimmingCharactersInSet(WhitespaceAndNewlineCharacterSet)

    return ["swiftc", "-sdk", sdkPath]
  }

  func compileModule(module: RoostfileModule) {
    let moduleFilePath = "build/\(module.name).swiftmodule"
    
    var arguments = commonCompilerArguments()

    var sources = [String]()

    for sourceDirectory in module.sources {
      let directory = (roostfile.directory as NSString).stringByAppendingPathComponent(sourceDirectory)

      sources.extend(scanDirectoryForSources(directory))
    }

    arguments.extend(sources)

    arguments.append("-emit-module-path")
    arguments.append(moduleFilePath)

    executeShellTaskWithArguments(arguments)

    println("Compiled module \(module.name) to \(moduleFilePath)")
  }

  func compile() {
    for (_, module) in roostfile.modules {
      compileModule(module)
    }

    let binFilePath = "bin/\(roostfile.name.lowercaseString)"

    var arguments: [String] = commonCompilerArguments()

    // Compile all of the sources
    arguments.extend(sourceFiles)

    // And set the location of the output executable
    arguments.append("-o")
    arguments.append(binFilePath)

    // Set search path
    arguments.append("-I build")

    executeShellTaskWithArguments(arguments)

    println("Compiled \(roostfile.name) to \(binFilePath)")
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
