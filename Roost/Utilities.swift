import Foundation

public func currentDirectoryPath() -> String {
  return (NSFileManager().currentDirectoryPath)
}

public func readFile(path: String) -> String {
  let url = NSURL(fileURLWithPath: path)!
  var error: NSError?

  let contents = NSString(contentsOfURL: url, encoding: NSUTF8StringEncoding, error: &error)

  if contents == nil {
    let errorString = error!.localizedDescription
    printAndExit("Error reading file: \(errorString)")
  }
  return contents! as String
}

public func printAndExit(string: String, status: Int32 = 1) {
  println(string)
  exit(status)
}

public func getFileModificationDate(path: String) -> NSDate? {
  var error: NSError?
  let manager = NSFileManager.defaultManager()

  let attributes = manager.attributesOfItemAtPath(path, error: &error)
  if attributes == nil { return nil }

  let maybeDate: AnyObject? = attributes![NSFileModificationDate]
  return maybeDate as! NSDate?
}

extension NSDate {
  func isNewerThan(other: NSDate) -> Bool {
    return (self.compare(other) == NSComparisonResult.OrderedDescending) ? true : false
  }
}
