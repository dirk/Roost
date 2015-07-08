[![Build Status][travis-image]][travis-url]

# Roost

A very basic WIP dependency manager and build tool for Swift.

## Setup and building

Roost is self-hosting, but also comes with a Makefile for bootstrapping.

```bash
git clone https://github.com/dirk/Roost.git
# Fetch the dependencies
cd vendor; carthage bootstrap; cd ..
# Build the binary using Make to invoke swiftc
make
# Use Roost to pull its dependencies
bin/roost update
# Then build Roost with itself (-B forces a rebuild)
bin/roost build -B
```

## Commands

* **`update`**: Clone or pull the dependencies.
* **`build`**: Build the dependencies (if any) and the project. Pass the `-B` flag to force a rebuild of everything.

## Under the hood

Roost looks for a `Roostfile.yaml` in the current directory. It parses that file and then executes the given command.

#### General program flow

1. **Parsing**: The `Roostfile.yaml` is parsed into a Roostfile object.
2. **Running**: The Runner object parses the command-line command and options, then invokes the function for that command.
3. **Packages** (when compiling): A Package object is derived from the Roostfile (packages are also derived for each dependency).


##### Roostfile vs. Package

A Roostfile object represents a parsed `Roostfile.yaml`, while a Package object represents the files, directories, objects, and so forth present in the filesystem for a given Roostfile. Roostfiles connect your local project to the outside world (fetching dependencies, publishing your project, etc.). Packages are how Roost manages actually building, linking, and other actions related to the current local state of your project.

## License

Licensed under the 3-clause BSD license. See [LICENSE](LICENSE) for details.

[travis-image]: https://img.shields.io/travis/dirk/Roost/master.svg?style=flat-square
[travis-url]: https://travis-ci.org/dirk/Roost
