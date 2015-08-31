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
  var sources                 = [String]()
  var frameworkSearchPaths    = [String]()
  var compilerOptions         = ""
  var precompileCommands      = [String]()
  var modules                 = Dictionary<String, Roostfile.Module>()
  var dependencies            = Array<Roostfile.Dependency>()
  var targetType: TargetType  = .Unknown
  var testTarget: TestTarget?
  var testCompilerOptions: String = ""

  struct ParsingError {
    let message: String
  }

  func parseFromString(string: String) -> ParsingError? {
    let yaml = Yaml.load(string)

    if let error = yaml.error {
      return ParsingError(message: error)
    }

    // Map names to processors
    let unfailableActionMap = [
      "name":                   self.parseName,
      "version":                self.parseVersion,
      "sources":                self.parseSources,
      "modules":                self.parseModules,
      "framework_search_paths": self.parseFrameworkSearchPaths,
      "target_type":            self.parseTargetType,
      "dependencies":           self.parseDependencies,
      "precompile_commands":    self.parsePrecompileCommands,
    ]
    let failableActionMap = [
      "test_target":            self.parseTestTarget,
      "compiler_options":       self.parseCompilerOptions,
    ]

    if let dictionary = yaml.value!.dictionary {
      for (keyYaml, valueYaml) in dictionary {
        if let key = keyYaml.string {
          if let action = failableActionMap[key] {
            let error = action(valueYaml)
            if error != nil { return error }

          } else if let action = unfailableActionMap[key] {
            action(valueYaml)

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

  func parseName(yaml: Yaml) {
    name = yaml.string!
  }

  /**
    Skip no-op.
  */
  func parseVersion(yaml: Yaml) {
    return
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

  func parseModules(yaml: Yaml) {
    for moduleYaml in yaml.array! {
      parseModule(moduleYaml)
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

  func parsePrecompileCommands(yaml: Yaml) {
    precompileCommands = yaml.array!.map { return $0.string! }
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
      parseGithubDependency(github, yaml: yaml)
    } else {
      println("Invalid dependency format"); exit(1)
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
    var testTarget = TestTarget()

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


  func validate() {
    // TODO: Implement some validations
    return
  }

  func inspect() {
    println("name: \(name)")
    println("sources: \(sources)")
    println("target_type: \(targetType.description.lowercaseString)")

    if dependencies.count > 0 {
      println("dependencies:")

      for dependency in dependencies {
        if let github = dependency.github {
          println("  - github: \(github)")
        } else {
          println("  - unknown")
        }
      }
    }

    if modules.count > 0 {
      println("modules:")

      for (key, module) in modules {
        println("  - name: \(module.name)")
        println("    sources: \(module.sources)")
      }
    }

    if frameworkSearchPaths.count > 0 {
      println("framework_search_paths: \(frameworkSearchPaths)")
    }

    // for (name, module) in modules {
    //   println("module  :")
    //   module.inspect()
    // }
  }

}// class Roostfile
