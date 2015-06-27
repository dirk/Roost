import Foundation

func main() {
  let fileManager = NSFileManager()

  let cwd = currentDirectoryPath()
  let path = NSString.pathWithComponents([cwd, "Roostfile"])

  if !fileManager.fileExistsAtPath(path) {
    printAndExit("Missing Roostfile in '\(cwd)'")
  }

  let pathURL = NSURL(fileURLWithPath: path)!

  var error: NSError?
  let contents = NSString(contentsOfURL: pathURL, encoding: NSUTF8StringEncoding, error: &error)

  if contents == nil {
    println(error); exit(1)
  }

  let roostfile = Roostfile()
  roostfile.directory = cwd
  roostfile.parseFromString(contents! as String)

  // roostfile.inspect()

  let package = roostfile.asPackage()

  package.compile()
}

main()
