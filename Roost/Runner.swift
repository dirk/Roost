import Foundation
import CommandLine

struct FlagsStorage {
  var MustRecompile: Bool = false
}

var Flags = FlagsStorage()

class Runner {
  var options = [String]()
  var roostfile: Roostfile!

  func run() {
    let argumentsCount = Process.arguments.count

    if argumentsCount < 2 {
      printAndExit("Usage: roost [command] [options]")
    }

    roostfile = parseRoostfile()

    let command = Process.arguments[1]
    options = Array(Process.arguments[2..<argumentsCount])

    switch command {
      case "build":  build()
      case "update": update()
      default:       printAndExit("Invalid command: '\(command)'")
    }
  }

  private func build() {
    parseOptionsForBuild()

    // roostfile.inspect()

    let package = roostfile.asPackage()
    let builder = Builder(package)

    builder.compile()
  }

  private func update() {
    let package = roostfile.asPackage()

    let vendorDirectory = package.vendorDirectory

    for dependency in roostfile.dependencies {
      let directory = dependency.inLocalDirectory(vendorDirectory)

      dependency.update(directory)
    }
  }


// Option parsing

  /**
    Utility for parsing the command-line options
  */
  private func parseWithOptions(commandOptions: Option...) {
    let cli = CommandLine(arguments: options)

    cli.addOptions(commandOptions)

    let (success, error) = cli.parse()

    if !success {
      printAndExit(error!)
    }
  }

  /**
    Parse the command-line option arguments for the `build` command.
  */
  private func parseOptionsForBuild() {
    let mustRecompile = BoolOption(shortFlag: "B",
                                   longFlag: "rebuild",
                                   helpMessage: "Rebuild package")

    parseWithOptions(mustRecompile)

    Flags.MustRecompile = mustRecompile.value
  }


// Utility functions

  private func findRoostfile() -> (String, String) {
    let cwd = currentDirectoryPath()
    let path = NSString.pathWithComponents([cwd, "Roostfile.yaml"])

    if !NSFileManager.defaultManager().fileExistsAtPath(path) {
      printAndExit("Missing Roostfile in '\(cwd)'")
    }

    return (cwd, path)
  }

  private func parseRoostfile() -> Roostfile {
    let (directory, path) = findRoostfile()
    let contents = readFile(path)

    let roostfile = Roostfile()
    roostfile.directory = directory
    roostfile.parseFromString(contents as String)

    return roostfile
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
