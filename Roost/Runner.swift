import Foundation
import CommandLine

struct FlagsStorage {
  var MustRecompile: Bool = false
  var Verbose: Bool = false
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
      case "list":    list()
      case "update":  update()
      case "test":    test()
      case "clean":   clean()
      default:        printAndExit("Invalid command: '\(command)'")
    }
  }


// Commands

  private func build() {
    parseOptionsForBuild()

    Builder(roostfile.asPackage()).compile()
  }

  private func update() {
    parseOptionsForUpdate()

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

  private func list() {
    let path = Index.findIndexFile()

    Index.read(path)
  }

  private func test() {
    parseOptionsForTest()

    if roostfile.testTarget == nil {
      printAndExit("Missing test target")
    }

    // Force it to be building the test executable
    roostfile.targetType = .Executable

    let testPackage = roostfile.asPackageForTest()

    let testEntrance = testPackage.sourceFiles.filter {
      return $0.contains("main.swift")
    }
    if testEntrance.count != 1 {
      printAndExit("Missing entrace 'main.swift' in test sources")
    }

    let builder = Builder(testPackage)
    let mainObject = "\(builder.buildDirectory)/main.swift.o"

    if fileExists(mainObject) {
      var error: NSError?
      NSFileManager.defaultManager().removeItemAtPath(mainObject, error: &error)

      if error != nil {
        printAndExit("Unable to remove entrace object file: \(error!.description)")
      }
    }

    Builder(testPackage).compile()

    TestRunner(testPackage).run()
  }

  private func clean() {
    print("Cleaning..."); stdoutFlush()

    let package = roostfile.asPackage()
    let buildDirectory = "\(package.directory)/build"
    let fileManager = NSFileManager()
    let enumerator = fileManager.enumeratorAtPath(buildDirectory)!

    var filesToClean = [String]()

    for file in enumerator {
      if !file.hasSuffix(".o") { continue }

      let path = "\(buildDirectory)/\(file as! String)"
      filesToClean.append(path)
    }

    for path in filesToClean {
      var error: NSError?
      fileManager.removeItemAtPath(path, error: &error)

      if let error = error {
        println() // Newline after the "Cleaning..." message above
        printAndExit("Error removing file: \(error.description)")
      }
    }
    println(" Done")
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

    let verbose = createVerboseOption()

    parseWithOptions(mustRecompile, verbose)

    Flags.MustRecompile = mustRecompile.value
    Flags.Verbose       = verbose.value
  }

  private func parseOptionsForTest() {
    let verbose = createVerboseOption()

    parseWithOptions(verbose)

    Flags.Verbose = verbose.value
  }

  private func parseOptionsForUpdate() {
    let verbose = createVerboseOption()

    parseWithOptions(verbose)

    Flags.Verbose = verbose.value
  }


// Utility functions

  /**
    Creates a BoolOption for parsing the "-v" verbose flag.
  */
  private func createVerboseOption() -> BoolOption {
    return BoolOption(shortFlag: "v",
                      longFlag: "verbose",
                      helpMessage: "Verbose logging")
  }

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
    println("  build    Build project")
    println("  inspect  Show project details")
    println("  list     List all packages in the index")
    println("  update   Update (or fetch if not present) project dependencies")
    println("  clean    Remove intermediate build files")
    println("")
  }

}
