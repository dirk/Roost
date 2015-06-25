import Foundation

class RoostfileModule {
  var name: String!
  var sources: [String] = []

  func inspect() {
    println("  name \(name)")
    println("  sources \(sources)")
  }
}
