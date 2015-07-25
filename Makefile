SWIFTC=swiftc -sdk $(shell xcrun --show-sdk-path)

SOURCES=$(shell find Roost -name '*.swift')

FRAMEWORKS=-F vendor/Carthage/Build/Mac -Xlinker -rpath -Xlinker @executable_path/../vendor/Carthage/Build/Mac

bin/roost: $(SOURCES) \
		build/Tasker.swiftmodule build/libTasker.a \
		build/MessagePack.swiftmodule build/libMessagePack.a
	$(eval sources = $(filter %.swift, $^))
	@# Build with the sources and the modules
	$(SWIFTC) $(sources) -I build -L build -lTasker -lMessagePack $(FRAMEWORKS) -o $@


build/Tasker.swiftmodule: Tasker/*.swift
	$(SWIFTC) -emit-module-path $@ $^

build/libTasker.a: build/tmp-Tasker.o
	libtool -o $@ $^

build/tmp-Tasker.o: Tasker/*.swift
	$(SWIFTC) -module-name Tasker -parse-as-library -emit-object -o $@ $^ 


build/MessagePack.swiftmodule: vendor/MessagePack/Source/*.swift
	$(SWIFTC) -emit-module-path $@ $^

build/libMessagePack.a: build/tmp-MessagePack.o
	libtool -o $@ $^

build/tmp-MessagePack.o: vendor/MessagePack/Source/*.swift
	$(SWIFTC) -module-name MessagePack -parse-as-library -emit-object -whole-module-optimization -o $@ $^ 

.PHONY: clean

clean:
	rm -f bin/roost
	rm build/*
