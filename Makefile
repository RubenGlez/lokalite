.PHONY: run build test release

run:
	swift run LokaliteApp

build:
	swift build -c release

test:
	swift test

release:
	@scripts/release.sh $(BUMP)
