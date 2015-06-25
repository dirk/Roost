SWIFTC=swiftc -sdk $(shell xcrun --show-sdk-path)

bin/roost: Roost/*.swift build/Tasker.swiftmodule
	$(eval sources = $(filter %.swift, $^))
	@# Build with the sources and the modules
	$(SWIFTC) $(sources) -I build -o $@

build/Tasker.swiftmodule: Tasker/*.swift
	$(SWIFTC) -emit-module-path $@ $^

.PHONY: clean

clean:
	rm -f bin/roost
