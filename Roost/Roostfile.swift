import Foundation
import Yaml

private let commentToken = "#"

let WhitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
let WhitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()

class Roostfile {
  var name: String!
  var directory: String!
  var sources              = [String]()
  var frameworkSearchPaths = [String]()
  var modules              = Dictionary<String, Roostfile.Module>()

  func parseFromString(string: String) {
    let yaml = Yaml.load(string).value!

    // Map names to processors
    let map = [
      "name":                 self.parseName,
      "sources":              self.parseSources,
      "module":               self.parseModule,
      "frameworkSearchPaths": self.parseFrameworkSearchPaths,
    ]
    
    for (keyYaml, valueYaml) in yaml.dictionary! {
      let key = keyYaml.string!

      if let action = map[key] {
        action(valueYaml)

      } else {
        println("Can't parse key \(key)")
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

    module.name = yaml["name"].string!
    module.sources = yaml["sources"].array!.map { (y: Yaml) in
      return y.string!
    }

    modules[module.name] = module
  }

  func parseFrameworkSearchPaths(yaml: Yaml) {
    frameworkSearchPaths = yaml.array!.map { (y: Yaml) in
      return y.string!
    }
  }


  func validate() {
    // TODO: Implement some validations
    return
  }

  func inspect() {
    println("name \(name)")
    println("sources \(sources)")

    for (name, module) in modules {
      println("module {")

      module.inspect()

      println("}")
    }
  }

}// class Roostfile
