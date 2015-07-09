import Foundation
import CommandLine

struct FlagsStorage {
  var MustRecompile: Bool = false
}

var Flags = FlagsStorage()

class Runner {
  var options = [String]()
  var roostfile: Roostfile!
  var command: String!

  func run() {
    let argumentsCount = Process.arguments.count

    if argumentsCount < 2 {
      printUsageAndCommands()
      exit(1)
    }

    roostfile = parseRoostfile()

    command = Process.arguments[1]
    options = Array(Process.arguments[2..<argumentsCount])

    switch command {
      case "build":   build()
      case "inspect": inspect()
      case "update":  update()
      default:        printAndExit("Invalid command: '\(command)'")
    }
  }

  private func build() {
    parseOptionsForBuild()

    Builder(roostfile.asPackage()).compile()
  }

  private func update() {
    let package = roostfile.asPackage()

    let vendorDirectory = package.vendorDirectory

    for dependency in roostfile.dependencies {
      let directory = dependency.inLocalDirectory(vendorDirectory)

      dependency.update(directory)
    }
  }

  private func inspect() {
    roostfile.inspect()
  }


// Option parsing

  private func optionParsingError(cli: CommandLine, _ error: String) {
    println(error)
    println("")
    cli.printUsage()
    println("")
    exit(1)
  }

  /**
    Utility for parsing the command-line options
  */
  private func parseWithOptions(commandOptions: Option...) {
    let optionsWithCommand = ["roost \(command)"] + options

    let cli = CommandLine(arguments: optionsWithCommand)

    cli.addOptions(commandOptions)

    let (success, error) = cli.parse(strict: true)

    if !success {
      optionParsingError(cli, error!)
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

  private func printUsageAndCommands() {
    println("Usage: roost [command] [options]\n")
    println("Available commands:\n")
    println("  build   Build project")
    println("  update  Update (or fetch if not present) project dependencies")
    println("")
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
