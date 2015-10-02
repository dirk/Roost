import Foundation

extension Roostfile {
  class Dependency {

    var github: String?

    var onlyTest: Bool = false

    // Roostfile of the dependency
    var roostfile: Roostfile?


  // Computed attributes

    var shortName: String {
      if let github = self.github {
        return github.componentsSeparatedByString("/").last!
      } else {
        fatalError("Can't determine shortname for dependency")
      }
    }

    var moduleName: String { return shortName }


  // Initializers

    init(github: String) {
      self.github = github
    }

    func sourceURL() -> String {
      return "https://github.com/\(github!).git"
    }

    func localDirectoryName() -> String {
      let github = self.github!
      let parts = github.componentsSeparatedByString("/")
      return parts.last!
    }

    func inLocalDirectory(directory: String) -> String {
      return "\(directory)/\(localDirectoryName())"
    }


  // Cloning and updating

    func update(directory: String) {
      let exists = NSFileManager.defaultManager().fileExistsAtPath(directory)

      if exists {
        pull(directory)
      } else {
        clone(directory)
      }
    }

    func clone(directory: String) {
      let cloneCommand = ["git", "clone", "-q", sourceURL(), directory]

      announceAndRunTask("Cloning dependency \(shortName)... ",
                         arguments: cloneCommand,
                         finished: "Cloned dependency \(shortName)")
    }

    func pull(directory: String) {
      let commandsArray = [
        "cd \(directory)",
        "git pull -q origin master",
      ]
      let commands = commandsArray.joinWithSeparator(" && ")

      announceAndRunTask("Pulling dependency \(shortName)... ",
                         arguments: ["sh", "-c", commands],
                         finished: "Pulled dependency \(shortName)")
    }// pullDependency


  }// Dependency
}// Roostfile
