import Foundation

extension Roostfile {
  class Dependency {
    var github: String?

    var shortname: String {
      get {
        if let github = self.github {
          return github.componentsSeparatedByString("/").last!
        } else {
          fatalError("Can't determine shortname for dependency")
        }
      }
    }


    init(github gh: String) {
      github = gh
    }

    func sourceURL() -> String {
      return "git@github.com:\(github!).git"
    }

    func localDirectoryName() -> String {
      let github = self.github!
      let parts = github.componentsSeparatedByString("/")
      return parts.last!
    }

  }// Dependency
}// Roostfile
