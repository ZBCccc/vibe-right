.PHONY: build test install clean

build:
	./Scripts/build.sh

test:
	./Scripts/test.sh

install: build
	./Scripts/install.sh

clean:
	rm -rf .build dist
