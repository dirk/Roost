import Speedy
import Nimble

class RoostfileSpec: Spec {
  var definition: String {
    get {
      return [
        "name: Test",
        "version: 0.1.2",
        "target_type: executable",
        "sources:",
        "  - TestFile.swift",
        "  - TestDirectory/",
        "",
        "dependencies:",
        "  - github: foo/Bar",
        "  - github: baz/Bop",
        "    only_test: true",
      ].joinWithSeparator("\n")
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

      it("should parse dependencies") {
        expect(r.dependencies.count).to(equal(2))
        expect(r.dependencies[0].github).to(equal("foo/Bar"))
        expect(r.dependencies[0].onlyTest).to(beFalsy())
        expect(r.dependencies[1].github).to(equal("baz/Bop"))
        expect(r.dependencies[1].onlyTest).to(beTruthy())
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

      it("should not parse bad dependencies") {
        let error = r.parseFromString("dependencies: a string")
        expect(error).toNot(beNil())
        expect(error!.message).to(contain("must be an array"))
      }
    }
  }
}
