import Foundation

class Package {
  var roostfile: Roostfile

  var sourceFiles: [String] = []

  init(_ r: Roostfile) {
    roostfile = r

    scanSources()
  }

  private func scanSources() {
    let directory = roostfile.directory as NSString
    let fileManager = NSFileManager()

    for source in roostfile.sources {
      if !(source as NSString).hasSuffix("/") {
        println("Cannot handle source pattern '\(source)'")
        continue
      }

      let path = directory.stringByAppendingPathComponent(source)
      let enumerator = fileManager.enumeratorAtPath(path)!

      for file in enumerator {
        let filePath = path.stringByAppendingPathComponent(file as! String)
        sourceFiles.append(filePath)
      }
    }
  }// scanSources()

}
