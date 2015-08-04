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

  var currentIndex: Int = 0

  init(_ name: String) {
    self.name = name
  }

  func addChild(group: Group) {
    let child = ChildGroup(index: currentIndex, group: group)

    childGroups.append(child)

    currentIndex += 1
  }
  func addChild(example: Example) {
    let child = ChildExample(index: currentIndex, example: example)

    childExamples.append(child)

    currentIndex += 1
  }
}
