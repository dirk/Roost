import Foundation
import CommandLine
import SwiftGit2

struct FlagsStorage {
  var MustRecompile: Bool = false
}

var Flags = FlagsStorage()

private func findRoostfile() -> (String, String) {
  let cwd = currentDirectoryPath()
  let path = NSString.pathWithComponents([cwd, "Roostfile.yaml"])

  if !NSFileManager.defaultManager().fileExistsAtPath(path) {
    printAndExit("Missing Roostfile in '\(cwd)'")
  }

  return (cwd, path)
}

func initializeFlags() {
  let environment = NSProcessInfo.processInfo().environment
  
  let mustRecompile = environment["MUST_RECOMPILE"] as! NSString?

  if let flag = mustRecompile {
    Flags.MustRecompile = flag.lowercaseString != "no"
  }
}

func main() {
  initializeFlags()

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

main()
