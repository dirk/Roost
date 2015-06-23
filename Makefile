SWIFTC=swiftc -sdk $(shell xcrun --show-sdk-path)

bin/roost: src/*.swift
	$(SWIFTC) $^ -o $@

.PHONY: clean

clean:
	rm -f bin/roost
