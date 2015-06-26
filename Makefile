SWIFTC=swiftc -sdk $(shell xcrun --show-sdk-path)

SOURCES=$(shell find Roost -name '*.swift')

bin/roost: $(SOURCES) build/Tasker.swiftmodule build/libTasker.a
	$(eval sources = $(filter %.swift, $^))
	@# Build with the sources and the modules
	$(SWIFTC) $(sources) -I build -L build -lTasker -o $@

build/Tasker.swiftmodule: Tasker/*.swift
	$(SWIFTC) -emit-module-path $@ $^

build/libTasker.a: build/tmp-Tasker.o
	libtool -o $@ $^

build/tmp-Tasker.o: Tasker/*.swift
	$(SWIFTC) -module-name Tasker -parse-as-library -emit-object -o $@ $^ 



.PHONY: clean

clean:
	rm -f bin/roost
	rm build/*
