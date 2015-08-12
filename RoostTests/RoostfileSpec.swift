import Speedy
import Nimble

class RoostfileSpec: Spec {
  var definition: String {
    get {
      return "\n".join([
        "name: Test",
        "version: 0.1.2",
        "target_type: executable",
      ])
    }
  }

  func spec() {
    describe("when parsing") {
      it("should parse basic properties") {
        let r = Roostfile()
        r.parseFromString(self.definition)

        expect(r.name).to(equal("Test"))
        expect(r.targetType).to(equal(TargetType.Executable))
      }
    }
  }
}
