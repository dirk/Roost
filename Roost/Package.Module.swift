import Foundation

extension Package {
  class Module {
    var module: Roostfile.Module
    var parent: Package
    var sourceFiles: [String] = []
    var lastModificationDate: NSDate = NSDate()

    var name: String {
      get { return module.name }
    }

    init(_ m: Roostfile.Module, parent p: Package) {
      module = m
      parent = p

      sourceFiles          = parent.scanSourcesDirectories(module.sources)
      lastModificationDate = parent.computeLastModificationDate(sourceFiles)
    }

  }// class Module
}
