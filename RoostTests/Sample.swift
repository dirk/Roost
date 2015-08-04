import Nimble

class SampleSpec: Spec {
  func spec() {
    describe("something") {
      it("should do something") {
        expect(1 + 1).to(equal(3))

        println("Hello world!")

        expect(1 + 1).to(equal(2))
      }
    }
  }
}
