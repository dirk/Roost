import Foundation

class CompileableObject: Compileable {
  let compileOptions: CompileOptions
  let primarySourceFile: String
  let otherSourceFiles: [String]
  let targetObjectFile: String

  var startedMessage: String
  var finishedMessage: String

  init(compileOptions: CompileOptions,
       primarySourceFile: String,
       otherSourceFiles: [String],
       targetObjectFile: String)
  {
    self.compileOptions    = compileOptions
    self.primarySourceFile = primarySourceFile
    self.otherSourceFiles  = otherSourceFiles
    self.targetObjectFile  = targetObjectFile

    let filename    = (primarySourceFile as NSString).lastPathComponent
    startedMessage  = "Compiling \(filename)... "
    finishedMessage = "Compiled \(filename)"
  }

  func compile() -> Int {
    // Arguments to be injected right after the '-c' flag in the arguments
    // to swiftc.
    var sourcesArguments = otherSourceFiles
    sourcesArguments.extend(["-primary-file", primarySourceFile])

    var arguments = compileOptions.argumentsForFrontend(sourcesArguments)
    arguments.extend(["-o", targetObjectFile])

    let status   = announceAndRunTask(startedMessage,
                                      arguments: arguments,
                                      finished: finishedMessage)

    return status
  }
}
