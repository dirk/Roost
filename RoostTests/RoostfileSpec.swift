import Speedy
import Nimble

class RoostfileSpec: Spec {
  var definition: String {
    get {
      return "\n".join([
        "name: Test",
        "version: 0.1.2",
        "target_type: executable",
        "sources:",
        "  - TestFile.swift",
        "  - TestDirectory/",
      ])
    }
  }

  func spec() {
    describe("when parsing valid Roostfiles") {
      var r: Roostfile!

      beforeEach {
        r = Roostfile()
        r.parseFromString(self.definition)
      }

      it("should parse basic properties") {
        expect(r.name).to(equal("Test"))
        expect(r.targetType).to(equal(TargetType.Executable))
      }

      it("should parse sources") {
        expect(r.sources.count).to(equal(2))
        expect(r.sources[0]).to(equal("TestFile.swift"))
        expect(r.sources[1]).to(equal("TestDirectory/"))
      }
    }
    describe("when parsing invalid Roostfiles") {
      var r: Roostfile!

      beforeEach {
        r = Roostfile()
      }

      it("should not parse invalid properties") {
        let error = r.parseFromString("bad_property: bad")
        expect(error).toNot(beNil())
        expect(error!.message).to(contain("bad_property"))
      }
    }
  }
}
