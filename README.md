# Roost

A very basic WIP dependency manager and build tool for Swift.

## Setup and building

Roost is self-hosting, but also comes with a Makefile for bootstrapping.

```bash
git clone https://github.com/dirk/Roost.git
# Fetch the dependencies
cd vendor; carthage update; cd ..
# Build the binary using Make to invoke swiftc
make
# Build the binary with itself (Roost invokes swiftc)
bin/roost
```

# License

Licensed under the 3-clause BSD license. See [LICENSE](LICENSE) for details.
