import Foundation
import CommandLine

struct FlagsStorage {
  var MustRecompile: Bool = false
}

var Flags = FlagsStorage()

class Runner {
  var options = [String]()

  func run() {
    let argumentsCount = Process.arguments.count

    if argumentsCount < 2 {
      printAndExit("Usage: roost [command] [options]")
    }

    let command = Process.arguments[1]
    options = Array(Process.arguments[2..<argumentsCount])

    switch command {
      case "build":
        build()
      default:
        printAndExit("Invalid command: '\(command)'")
    }
  }

  func parseWithOptions(commandOptions: Option...) {
    let cli = CommandLine(arguments: options)

    cli.addOptions(commandOptions)

    let (success, error) = cli.parse()

    if !success {
      printAndExit(error!)
    }
  }

  func parseOptionsForBuild() {
    let mustRecompile = BoolOption(shortFlag: "B",
                                   longFlag: "rebuild",
                                   helpMessage: "Rebuild package")

    parseWithOptions(mustRecompile)

    Flags.MustRecompile = mustRecompile.value
  }

  func build() {
    parseOptionsForBuild()

    let (directory, path) = findRoostfile()
    let contents = readFile(path)

    let roostfile = Roostfile()
    roostfile.directory = directory
    roostfile.parseFromString(contents as String)

    // roostfile.inspect()

    let package = roostfile.asPackage()
    let builder = Builder(package)

    builder.compile()
  }

  private func findRoostfile() -> (String, String) {
    let cwd = currentDirectoryPath()
    let path = NSString.pathWithComponents([cwd, "Roostfile.yaml"])

    if !NSFileManager.defaultManager().fileExistsAtPath(path) {
      printAndExit("Missing Roostfile in '\(cwd)'")
    }

    return (cwd, path)
  }

  // private func initializeFlags() {
  //   let environment = NSProcessInfo.processInfo().environment
  //
  //   let mustRecompile = environment["MUST_RECOMPILE"] as! NSString?
  //
  //   if let flag = mustRecompile {
  //     Flags.MustRecompile = flag.lowercaseString != "no"
  //   }
  // }
}
