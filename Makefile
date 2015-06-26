SWIFTC=swiftc -sdk $(shell xcrun --show-sdk-path)

SOURCES=$(shell find Roost -name '*.swift')

bin/roost: $(SOURCES) build/Tasker.swiftmodule build/libTasker.dylib
	$(eval sources = $(filter %.swift, $^))
	@# Build with the sources and the modules
	$(SWIFTC) $(sources) -I build -L build -lTasker -o $@

build/Tasker.swiftmodule: Tasker/*.swift
	$(SWIFTC) -emit-module-path $@ $^

build/libTasker.dylib: Tasker/*.swift
	$(SWIFTC) -emit-library -o $@ $^ 

.PHONY: clean

clean:
	rm -f bin/roost
