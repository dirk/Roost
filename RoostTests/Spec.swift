import Foundation
import Nimble

protocol Spec {
  func spec()
}

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


class SpecRunner {
  private let Running = 1
  private let Done    = 2

  let specs: [Spec]
  var lock: NSConditionLock!

  init(_ specs: [Spec]) {
    self.specs = specs
  }

  func run() {
    for spec in specs {
      lock = NSConditionLock(condition: Running)

      let thread = NSThread(target: self, selector: "runSpec:", object: (spec as! AnyObject))
      thread.start()

      lock.lockWhenCondition(Done)
    }
  }

  func prepareForSpec(spec: Spec) {
    let handler = NimbleAssertionHandlerAdapter(spec)

    NimbleAssertionHandler = handler
  }

  @objc func runSpec(aSpec: AnyObject?) {
    assert(lock.tryLock() == true, "Unable to acquire lock")

    let spec = aSpec as! Spec

    prepareForSpec(spec)

    spec.spec()

    lock.unlockWithCondition(Done)
  }
}

func testSpecs(specs: [Spec]) {
  setExceptionHandler()

  let runner = SpecRunner(specs)

  runner.run()
}
