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

  init?(string: String) {
    switch string.lowercaseString {
      case "unknown":    self = .Unknown
      case "executable": self = .Executable
      case "framework":  self = .Framework
      case "module":     self = .Module
      default:           return nil
    }
  }

  var description: String {
    switch self {
      case .Unknown:    return "Unknown"
      case .Executable: return "Executable"
      case .Framework:  return "Framework"
      case .Module:     return "Module"
    }
  }
}

class Roostfile {
  var name: String!
  var directory: String!
  var sources                  = [String]()
  var frameworkSearchPaths     = [String]()
  var compilerOptions          = ""
  var linkerOptions            = ""
  var precompileCommands       = [String]()
  var modules                  = Dictionary<String, Roostfile.Module>()
  var dependencies             = Array<Roostfile.Dependency>()
  var targetType: TargetType   = .Unknown
  var targetPlatform: Platform = MacOSXv10_11
  var testTarget: TestTarget?
  var testCompilerOptions: String = ""
  var testLinkerOptions: String   = ""

  struct ParsingError: ErrorType {
    let message: String
  }

  func parseFromString(string: String) -> ParsingError? {
    let yaml = Yaml.load(string)

    if let error = yaml.error {
      return ParsingError(message: error)
    }

    // Map names to parsing functions
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

    guard let dictionary = yaml.value!.dictionary else {
      return ParsingError(message: "Can't parse document; expected dictionary") }

    for (keyYaml, valueYaml) in dictionary {
      guard let key = keyYaml.string else {
        return ParsingError(message: "Can't parse key; expected string") }

      guard let action = actionMap[key] else {
        return ParsingError(message: "Can't parse key '\(key)'") }

      if let error = action(valueYaml) {
        return error
      }
    }// for

    return nil
  }// parseFromString

  func asPackage() -> Package {
    return Package(self)
  }

  func asPackageForTest() -> Package {
    return Package(testSources: testTarget!.sources, forRoostfile: self)
  }

  func parseName(yaml: Yaml) -> ParsingError? {
    guard let name = yaml.string else {
      return ParsingError(message: "Invalid name; expected string") }

    self.name = name
    return nil
  }

  /**
    Skip no-op.
  */
  func parseVersion(yaml: Yaml) -> ParsingError? {
    return nil
  }

  func parseSources(yaml: Yaml) -> ParsingError? {
    guard let sourcesYaml = yaml.array else {
      return ParsingError(message: "Cannot parse sources") }

    var sources = [String]()

    for maybeSource in sourcesYaml {
      guard let source = maybeSource.string else {
        return ParsingError(message: "Can't parse source; expected string") }

      sources.append(source)
    }

    self.sources = sources
    return nil
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
    guard let searchPaths = yaml.array else {
      return ParsingError(message: "Invalid framework search paths; expected array")
    }

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
  }

  func parsePrecompileCommands(yaml: Yaml) -> ParsingError? {
    guard let precompileCommands = yaml.array else {
      return ParsingError(message: "Invalid precompile commands; expected array")
    }

    var commands = [String]()

    for commandYaml in precompileCommands {
      if let command = commandYaml.string {
        commands.append(command)
      } else {
        return ParsingError(message: "Invalid precompile command; expected string")
      }
    }

    self.precompileCommands = commands
    return nil
  }

  func parseTargetType(yaml: Yaml) -> ParsingError? {
    guard let typeString = yaml.string else {
      return ParsingError(message: "Invalid target type; expected string")
    }

    guard let type = TargetType(string: typeString) else {
      return ParsingError(message: "Invalid target type '\(typeString)'")
    }

    targetType = type
    return nil
  }

  func parseDependencies(yaml: Yaml) -> ParsingError? {
    guard let deps = yaml.array else {
      return ParsingError(message: "Dependencies must be an array")
    }

    for dep in deps {
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

    guard let sources = yaml["sources"].array else {
      return ParsingError(message: "Missing `sources` array in test target")
    }

    var testTargetSources = [String]()
    for s in sources {
      if let s = s.string {
        testTargetSources.append(s)
      } else {
        return ParsingError(message: "Invalid test target source; expected string")
      }
    }
    testTarget.sources = testTargetSources

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
    guard let options = yaml.string else {
      return ParsingError(message: "Invalid (non-string) compiler options")
    }

    self.compilerOptions = options
    return nil
  }
  func parseLinkerOptions(yaml: Yaml) -> ParsingError? {
    guard let options = yaml.string else {
      return ParsingError(message: "Invalid (non-string) compiler options")
    }

    self.linkerOptions = options
    return nil
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
