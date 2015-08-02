func describe(name: String, definition: () -> ()) {
  definition()
}

testSpecs([
  SampleSpec(),
])
