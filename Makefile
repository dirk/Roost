SWIFTC=swiftc -sdk $(shell xcrun --show-sdk-path)

bin/roost: Roost/*.swift
	$(SWIFTC) $^ -o $@

.PHONY: clean

clean:
	rm -f bin/roost
