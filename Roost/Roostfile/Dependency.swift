import Foundation

extension Roostfile {
  class Dependency {
    var github: String?

    // Roostfile of the dependency
    var roostfile: Roostfile?


  // Computed attributes

    var shortName: String {
      get {
        if let github = self.github {
          return github.componentsSeparatedByString("/").last!
        } else {
          fatalError("Can't determine shortname for dependency")
        }
      }
    }

    var moduleName: String {
      get {
        return shortName
      }
    }


  // Initializers

    init(github gh: String) {
      github = gh
    }

    func sourceURL() -> String {
      return "https://github.com/\(github!).git"
    }

    func localDirectoryName() -> String {
      let github = self.github!
      let parts = github.componentsSeparatedByString("/")
      return parts.last!
    }

  }// Dependency
}// Roostfile
