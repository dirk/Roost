import Foundation

extension Roostfile {
  class Module {
    var name: String!
    var sources: [String] = []

    func inspect() {
      println("  name \(name)")
      println("  sources \(sources)")
    }
  }
}
