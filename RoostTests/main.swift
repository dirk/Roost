import Nimble

class NimbleAssertionHandlerAdapter: AssertionHandler {
  func assert(assertion: Bool, message: FailureMessage, location: SourceLocation) {
    if assertion { return }

    println(message.stringValue)
    println("  \(location.description)\n")
  }
}

NimbleAssertionHandler = NimbleAssertionHandlerAdapter()

expect(1 + 1).to(equal(3))
