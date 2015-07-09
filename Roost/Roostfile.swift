import Foundation
import Yaml

private let commentToken = "#"

let WhitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
let WhitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()

enum TargetType: Printable {
  case Unknown
  case Executable
  case Framework
  case Module

  var description: String {
    switch self {
      case .Unknown:    return "Unknown"
      case .Executable: return "Executable"
      case .Framework:  return "Framework"
      case .Module:     return "Module"
    }
  }

  static func fromString(string: String) -> TargetType? {
    switch string.lowercaseString {
      case "unknown":    return .Unknown
      case "executable": return .Executable
      case "framework":  return .Framework
      case "module":     return .Module
      default:           return nil
    }
  }
}

class Roostfile {
  var name: String!
  var directory: String!
  var sources                = [String]()
  var frameworkSearchPaths   = [String]()
  var modules                = Dictionary<String, Roostfile.Module>()
  var dependencies           = Array<Roostfile.Dependency>()
  var targetType: TargetType = .Unknown

  func parseFromString(string: String) {
    let yaml = Yaml.load(string).value!

    // Map names to processors
    let map = [
      "name":                   self.parseName,
      "sources":                self.parseSources,
      "module":                 self.parseModule,
      "framework_search_paths": self.parseFrameworkSearchPaths,
      "target_type":            self.parseTargetType,
      "dependencies":           self.parseDependencies,
    ]
    
    for (keyYaml, valueYaml) in yaml.dictionary! {
      if let key = keyYaml.string {
        if let action = map[key] {
          action(valueYaml)
          continue
        } else {
          println("Can't parse key '\(key)''")
        }
      } else {
        println("Can't parse key")
      }
    }
  }// parseFromString

  func asPackage() -> Package {
    return Package(self)
  }

  func parseName(yaml: Yaml) {
    name = yaml.string!
  }

  func parseSources(yaml: Yaml) {
    if let sourcesYamls = yaml.array {
      sources = sourcesYamls.map { (s) in
        return s.string!
      }
    } else {
      println("Cannot parse sources")
    }
  }

  func parseModule(yaml: Yaml) {
    var module = Roostfile.Module()
    var errored = false

    if let name = yaml["name"].string {
      module.name = name
    } else {
      println("Unable to parse module name")
      errored = true
    }

    if let sources = yaml["sources"].array {
      var parsedSources = [String]()

      for y in sources {
        if let source = y.string {
          parsedSources.append(source)
        } else {
          println("Unable to parse module source")
        }
      }

      module.sources = parsedSources
    } else {
      println("Unable to parse module sources")
      errored = true
    }

    if errored { return }

    modules[module.name] = module
  }

  func parseFrameworkSearchPaths(yaml: Yaml) {
    frameworkSearchPaths = yaml.array!.map { (y: Yaml) in
      return y.string!
    }
  }

  func parseTargetType(yaml: Yaml) {
    let typeString = yaml.string

    if typeString == nil {
      println("Invalid target type: expected string")
    }

    if let type = TargetType.fromString(typeString!) {
      targetType = type
    } else {
      println("Invalid target type '\(typeString)'")
    }
  }

  func parseDependencies(yaml: Yaml) {
    let deps = yaml.array

    if deps == nil {
      println("Dependencies must be an array"); exit(1)
    }

    for dep in deps! {
      parseDependency(dep)
    }
  }

  func parseDependency(yaml: Yaml) {
    if let github = yaml["github"].string {
      parseGithubDependency(github)
    } else {
      println("Invalid dependency format"); exit(1)
    }
  }

  func parseGithubDependency(github: String) {
    dependencies.append(Dependency(github: github))
  }


  func validate() {
    // TODO: Implement some validations
    return
  }

  func inspect() {
    println("name: \(name)")
    println("sources: \(sources)")

    for dependency in dependencies {
      println("dependency:")
      
      if let github = dependency.github {
        println("  github: \(github)")
      } else {
        println("  unknown")
      }
    }

    // for (name, module) in modules {
    //   println("module  :")
    //   module.inspect()
    // }
  }

}// class Roostfile
