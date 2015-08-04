import Nimble

class SampleSpec: Spec {
  func spec() {
    describe("something") {
      it("shouldn't pass") {
        expect(1 + 1).to(equal(3))
      }
      it("should pass") {
        expect(1 + 1).to(equal(2))
      }
    }
  }
}
