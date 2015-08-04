class Example {
  let name: String
  let block: () -> ()

  init(_ name: String, _ block: () -> ()) {
    self.name  = name
    self.block = block
  }
}


class Group {
  struct ChildGroup {
    let index: Int
    let group: Group
  }
  struct ChildExample {
    let index: Int
    let example: Example
  }

  let name: String
  var childGroups = [ChildGroup]()
  var childExamples = [ChildExample]()
  var parent: Group? = nil

  init(_ name: String) {
    self.name = name
  }

  func addChild(group: Group) {
    childGroups.append(ChildGroup(index: 0, group: group))
  }
  func addChild(example: Example) {
    childExamples.append(ChildExample(index: 0, example: example))
  }
}
