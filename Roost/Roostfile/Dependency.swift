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
      let cloneCommand = "git clone -q \(sourceURL()) \(directory)"

      announceAndRunTask("Cloning dependency \(shortName)... ",
                         arguments: ["-c", cloneCommand],
                         finished: "Cloned dependency \(shortName)")
    }

    func pull(directory: String) {
      let commandsArray = [
        "cd \(directory)",
        "git pull -q origin master",
      ]
      let commands = " && ".join(commandsArray)

      announceAndRunTask("Pulling dependency \(shortName)... ",
                         arguments: ["-c", commands],
                         finished: "Pulled dependency \(shortName)")
    }// pullDependency


  }// Dependency
}// Roostfile
