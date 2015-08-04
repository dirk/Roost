import Foundation
import Nimble

class NimbleAssertionHandlerAdapter: AssertionHandler {
  let spec: Spec

  init(_ spec: Spec) {
    self.spec = spec
  }

  func assert(assertion: Bool, message: FailureMessage, location: SourceLocation) {
    if assertion { return }

    println(message.stringValue)
    println("  \(location.description)\n")
  }
}

protocol Spec {
  func spec()
}


let SpecRunning = 1
let SpecDone    = 2

private var currentGroup: Group! = nil

class SpecRunner {
  let specs: [Spec]
  var lock: NSConditionLock!

  init(_ specs: [Spec]) {
    self.specs = specs
  }

  func run() {
    println("Running \(specs.count) specs:")

    for spec in specs {
      lock = NSConditionLock(condition: SpecRunning)

      let thread = NSThread(target: self, selector: "runSpec:", object: (spec as! AnyObject))
      thread.start()

      let timeout: NSTimeInterval = 2; // 2 seconds in the future
      let timeoutDate = NSDate(timeIntervalSinceNow: timeout)

      let didntTimeout = lock.lockWhenCondition(SpecDone, beforeDate: timeoutDate)

      if !didntTimeout {
        println("Spec timed out")
      }

      // Unlock it so it can be safely deallocated
      lock.unlock()
    }
  }

  func prepareForSpec(spec: Spec) {
    let handler = NimbleAssertionHandlerAdapter(spec)

    // NimbleAssertionHandler = handler

    // Silence assertions on this thread
    RSilentAssertionHandler.setup()

    let className = getClassNameOfObject(spec as! AnyObject)

    currentGroup = Group(className)
  }

  @objc func runSpec(aSpec: AnyObject?) {
    assert(lock.tryLock() == true, "Unable to acquire lock")

    let spec = aSpec as! Spec

    prepareForSpec(spec)

    let topLevelGroup = currentGroup

    // Process the definitions
    spec.spec()

    runGroup(topLevelGroup, indent: 0)

    lock.unlockWithCondition(SpecDone)
  }

  func runGroup(group: Group, indent: Int) {
    let i = " ".repeat(indent * 2)

    println("\(i)  \(group.name)")

    for childExample in group.childExamples {
      let example = childExample.example
      var exception: NSException! = nil

      let tryBlock = {
        example.block()
      }
      let catchBlock = { (caughtException: NSException!) in
        exception = caughtException
      }

      let didError = RTryCatch(tryBlock, catchBlock)

      let marker = (didError ? "✓".colorize(.Green) : "✗".colorize(.Red))

      println("\(i)\(marker) \(example.name)")

      if let e = exception {
        println("\(i)    \(e)")
      }
    }

    for childGroup in group.childGroups {
      let group = childGroup.group

      runGroup(group, indent: indent + 1)
    }
  }// runGroup
}

func describe(name: String, definition: () -> ()) {
  let group = Group(name)
  group.parent = currentGroup
  group.parent!.addChild(group)

  currentGroup = group

  definition()

  // Restore parent
  currentGroup = group.parent!
}

func it(name: String, block: () -> ()) {
  let example = Example(name, block)

  currentGroup.addChild(example)
}

func testSpecs(specs: [Spec]) {
  RSetupExceptionHandler()

  let runner = SpecRunner(specs)

  runner.run()
}
