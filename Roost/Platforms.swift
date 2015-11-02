struct Platform {
  let targetName: String
  let versionMin: String
}

let MacOSXv10_10 = Platform(
  targetName: "x86_64-apple-darwin14.4.0",
  versionMin: "10.10.0"
)

let MacOSXv10_11 = Platform(
  targetName: "x86_64-apple-darwin15.0.0",
  versionMin: "10.11.0"
)
