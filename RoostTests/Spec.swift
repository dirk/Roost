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

let SpecRunning = 1
let SpecDone    = 2

class SpecRunner {
  let specs: [Spec]
  var lock: NSConditionLock!

  init(_ specs: [Spec]) {
    self.specs = specs
  }

  func run() {
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
  }

  @objc func runSpec(aSpec: AnyObject?) {
    assert(lock.tryLock() == true, "Unable to acquire lock")

    let spec = aSpec as! Spec

    prepareForSpec(spec)

    let tryBlock = { spec.spec() }
    let catchBlock = { (exception: NSException!) in
      println(exception)
    }

    let didError = RTryCatch(tryBlock, catchBlock)

    lock.unlockWithCondition(SpecDone)
  }
}

func testSpecs(specs: [Spec]) {
  RSetupExceptionHandler()

  let runner = SpecRunner(specs)

  runner.run()
}
