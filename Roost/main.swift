import Foundation
import CommandLine
import SwiftGit2

private func findRoostfile() -> (String, String) {
  let cwd = currentDirectoryPath()
  let path = NSString.pathWithComponents([cwd, "Roostfile.yaml"])

  if !NSFileManager.defaultManager().fileExistsAtPath(path) {
    printAndExit("Missing Roostfile in '\(cwd)'")
  }

  return (cwd, path)
}

func main() {
  let (directory, path) = findRoostfile()
  let contents = readFile(path)

  let roostfile = Roostfile()
  roostfile.directory = directory
  roostfile.parseFromString(contents as String)

  // roostfile.inspect()

  let package = roostfile.asPackage()

  package.compile()
}

main()
