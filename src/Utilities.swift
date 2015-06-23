import Foundation

public func currentDirectoryPath() -> String {
  return (NSFileManager().currentDirectoryPath)
}

public func printAndExit(string: String, status: Int32 = 1) {
  println(string)
  exit(status)
}
