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
