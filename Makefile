VERSION ?= 1.0.0
CONTENT_VERSION := $(shell /usr/bin/python3 -c "import json;print(json.load(open('Sources/MochiMate/Resources/Content/content.json'))['version'])")
APP     := build/MochiMate.app
DMG     := build/MochiMate-$(VERSION).dmg
CONTENT := build/mochimate-content-$(CONTENT_VERSION).zip
STAGE   := build/dmg-stage

.PHONY: help app run dmg content sprites clean

help:
	@echo "make app       build $(APP) (sprites + release build + ad-hoc signing)"
	@echo "make run       build and open the app"
	@echo "make dmg       package $(DMG)  (VERSION=x.y.z sets the app version)"
	@echo "make content   package the dialogue/audio pack as $(CONTENT)"
	@echo "make sprites   regenerate the sprite sheets only"
	@echo "make clean     remove build output"
	@echo "Set SIGN_IDENTITY to sign with a real certificate instead of ad-hoc."

app:
	VERSION=$(VERSION) ./scripts/build-app.sh

run: app
	open $(APP)

dmg: app
	rm -rf $(STAGE) $(DMG)
	mkdir -p $(STAGE)
	cp -R $(APP) $(STAGE)/
	ln -s /Applications $(STAGE)/Applications
	hdiutil create -volname MochiMate -srcfolder $(STAGE) -ov -format UDZO $(DMG)
	rm -rf $(STAGE)
	hdiutil verify $(DMG)

content:
	mkdir -p build
	rm -f $(CONTENT)
	cd Sources/MochiMate/Resources/Content && /usr/bin/zip -qr ../../../../$(CONTENT) . -x '.*'
	@echo "Built $(CONTENT)"

sprites:
	swift run -c release SpriteGen

clean:
	rm -rf build
	swift package clean
