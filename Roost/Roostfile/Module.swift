import Foundation

extension Roostfile {
  class Module {
    var name: String!
    var sources: [String] = []

    func inspect() {
      print("  name \(name)")
      print("  sources \(sources)")
    }
  }
}
