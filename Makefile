.PHONY: run build test install release

run:
	swift run LokaliteApp

build:
	swift build -c release

test:
	swift test

install:
	swift build -c release
	.build/release/lokalite install

release:
	@scripts/release.sh $(BUMP)
