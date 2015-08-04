import Foundation

extension String {
  func repeat(n: Int) -> String {
    if n == 0 { return "" }

    var result = self

    for _ in 1 ..< n { result.extend(self) }

    return result
  }
}

func getClassNameOfObject(object: AnyObject) -> String {
  return NSStringFromClass(object.dynamicType)
    .componentsSeparatedByString(".").last!
}

// Colorization utilities

enum ANSIColor: Int {
  case Black   = 0
  case Red     = 1
  case Green   = 2
  case Yellow  = 3
  case Blue    = 4
  case Magenta = 5
  case Cyan    = 6
  case White   = 7
  case Default = 9
}

extension String {
  func colorize(foregroundColor: ANSIColor) -> String {
    let before = "\u{001B}[0;3\(foregroundColor.rawValue)m"
    let after  = "\u{001B}[0;3\(ANSIColor.Default.rawValue)m"

    return "\(before)\(self)\(after)"
  }
}
