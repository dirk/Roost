class Example {
  let name: String
  let block: () -> ()

  init(_ name: String, _ block: () -> ()) {
    self.name  = name
    self.block = block
  }
}


class Group {

  enum Child {
    case ChildGroup(Group)
    case ChildExample(Example)
  }

  let name: String
  var children = [Child]()
  var parent: Group? = nil

  var currentIndex: Int = 0

  init(_ name: String) {
    self.name = name
  }

  func addChild(group: Group) {
    children.append(.ChildGroup(group))
  }
  func addChild(example: Example) {
    children.append(.ChildExample(example))
  }
}
