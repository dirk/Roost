import Foundation
import Yaml

private let commentToken = "#"

let WhitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
let WhitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()

enum TargetType: CustomStringConvertible {
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
  var sources                 = [String]()
  var frameworkSearchPaths    = [String]()
  var compilerOptions         = ""
  var linkerOptions           = ""
  var precompileCommands      = [String]()
  var modules                 = Dictionary<String, Roostfile.Module>()
  var dependencies            = Array<Roostfile.Dependency>()
  var targetType: TargetType  = .Unknown
  var testTarget: TestTarget?
  var testCompilerOptions: String = ""
  var testLinkerOptions: String   = ""

  struct ParsingError {
    let message: String
  }

  func parseFromString(string: String) -> ParsingError? {
    let yaml = Yaml.load(string)

    if let error = yaml.error {
      return ParsingError(message: error)
    }

    // Map names to processors
    let actionMap = [
      "compiler_options":       self.parseCompilerOptions,
      "dependencies":           self.parseDependencies,
      "framework_search_paths": self.parseFrameworkSearchPaths,
      "linker_options":         self.parseLinkerOptions,
      "modules":                self.parseModules,
      "name":                   self.parseName,
      "precompile_commands":    self.parsePrecompileCommands,
      "sources":                self.parseSources,
      "target_type":            self.parseTargetType,
      "test_target":            self.parseTestTarget,
      "version":                self.parseVersion,
    ]

    if let dictionary = yaml.value!.dictionary {
      for (keyYaml, valueYaml) in dictionary {
        if let key = keyYaml.string {
          if let action = actionMap[key] {
            let error = action(valueYaml)
            if error != nil { return error }

          } else {
            return ParsingError(message: "Can't parse key '\(key)'")
          }
          continue
        } else {
          return ParsingError(message: "Can't parse key")
        }
      }// for

    } else {
      return ParsingError(message: "Can't parse document; expected dictionary")
    }

    return nil
  }// parseFromString

  func asPackage() -> Package {
    return Package(self)
  }

  func asPackageForTest() -> Package {
    return Package(testSources: testTarget!.sources, forRoostfile: self)
  }

  func parseName(yaml: Yaml) -> ParsingError? {
    if let name = yaml.string {
      self.name = name
      return nil
    } else {
      return ParsingError(message: "Invalid name; expected string")
    }
  }

  /**
    Skip no-op.
  */
  func parseVersion(yaml: Yaml) -> ParsingError? {
    return nil
  }

  func parseSources(yaml: Yaml) -> ParsingError? {
    if let sourcesYamls = yaml.array {
      sources = sourcesYamls.map { (s) in
        return s.string!
      }
      return nil
    } else {
      return ParsingError(message: "Cannot parse sources")
    }
  }

  func parseModules(yaml: Yaml) -> ParsingError? {
    for moduleYaml in yaml.array! {
      if let error = parseModule(moduleYaml) {
        return error
      }
    }

    return nil
  }

  func parseModule(yaml: Yaml) -> ParsingError? {
    let module = Roostfile.Module()

    if let name = yaml["name"].string {
      module.name = name
    } else {
      return ParsingError(message: "Unable to parse module name")
    }

    if let sources = yaml["sources"].array {
      var parsedSources = [String]()

      for y in sources {
        if let source = y.string {
          parsedSources.append(source)
        } else {
          return ParsingError(message: "Unable to parse module source")
        }
      }

      module.sources = parsedSources
    } else {
      return ParsingError(message: "Unable to parse module sources; expected array")
    }

    modules[module.name] = module
    return nil
  }

  func parseFrameworkSearchPaths(yaml: Yaml) -> ParsingError? {
    if let searchPaths = yaml.array {
      var frameworkSearchPaths = [String]()

      for path in searchPaths {
        if let path = path.string {
          frameworkSearchPaths.append(path)
        } else {
          return ParsingError(message: "Invalid framework search path; expected string")
        }
      }

      self.frameworkSearchPaths = frameworkSearchPaths
      return nil

    } else {
      return ParsingError(message: "Invalid framework search paths; expected array")
    }
  }

  func parsePrecompileCommands(yaml: Yaml) -> ParsingError? {
    var commands = [String]()

    if let precompileCommands = yaml.array {
      for commandYaml in precompileCommands {
        if let command = commandYaml.string {
          commands.append(command)
        } else {
          return ParsingError(message: "Invalid precompile command; expected string")
        }
      }
    } else {
      return ParsingError(message: "Invalid precompile commands; expected array")
    }

    self.precompileCommands = commands
    return nil
  }

  func parseTargetType(yaml: Yaml) -> ParsingError? {
    let typeString = yaml.string

    if typeString == nil {
      return ParsingError(message: "Invalid target type; expected string")
    }

    if let type = TargetType.fromString(typeString!) {
      targetType = type
    } else {
      return ParsingError(message: "Invalid target type '\(typeString)'")
    }

    return nil
  }

  func parseDependencies(yaml: Yaml) -> ParsingError? {
    let deps = yaml.array

    if deps == nil {
      return ParsingError(message: "Dependencies must be an array")
    }

    for dep in deps! {
      if let error = parseDependency(dep) {
        return error
      }
    }

    return nil
  }

  func parseDependency(yaml: Yaml) -> ParsingError? {
    if let github = yaml["github"].string {
      parseGithubDependency(github, yaml: yaml)
      return nil
    } else {
      return ParsingError(message: "Invalid dependency format")
    }
  }

  func parseGithubDependency(github: String, yaml: Yaml) {
    let dep = Dependency(github: github)

    if let onlyTest = yaml["only_test"].bool {
      dep.onlyTest = onlyTest
    }

    dependencies.append(dep)
  }

  func parseTestTarget(yaml: Yaml) -> ParsingError? {
    let testTarget = TestTarget()

    if let hasSources = yaml["sources"].array {
      testTarget.sources = hasSources.map { (s) in
        return s.string!
      }
    } else {
      return ParsingError(message: "Missing `sources` array in test target")
    }

    if let options = yaml["compiler_options"].string {
      testCompilerOptions = options
    }
    if let options = yaml["linker_options"].string {
      testLinkerOptions = options
    }

    self.testTarget = testTarget
    return nil
  }

  func parseCompilerOptions(yaml: Yaml) -> ParsingError? {
    let options = yaml.string

    if options == nil {
      return ParsingError(message: "Invalid (non-string) compiler options")
    }

    self.compilerOptions = options!
    return nil
  }
  func parseLinkerOptions(yaml: Yaml) -> ParsingError? {
    if let options = yaml.string {
      self.linkerOptions = options
      return nil
    } else {
      return ParsingError(message: "Invalid (non-string) compiler options")
    }
  }


  func validate() {
    // TODO: Implement some validations
    return
  }

  func inspect() {
    print("name: \(name)")
    print("sources: \(sources)")
    print("target_type: \(targetType.description.lowercaseString)")

    if dependencies.count > 0 {
      print("dependencies:")

      for dependency in dependencies {
        if let github = dependency.github {
          print("  - github: \(github)")
        } else {
          print("  - unknown")
        }
      }
    }

    if modules.count > 0 {
      print("modules:")

      for (_, module) in modules {
        print("  - name: \(module.name)")
        print("    sources: \(module.sources)")
      }
    }

    if frameworkSearchPaths.count > 0 {
      print("framework_search_paths: \(frameworkSearchPaths)")
    }

    // for (name, module) in modules {
    //   print("module  :")
    //   module.inspect()
    // }
  }

}// class Roostfile
