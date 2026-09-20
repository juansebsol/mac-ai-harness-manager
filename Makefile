.PHONY: build run test web web-build web-lint gallery
build:
	./apps/mac/Scripts/build.sh Release
run: build
	open "apps/mac/build/Harness Manager.app"
test:
	./apps/mac/Scripts/test-workflows.sh
web:
	cd apps/web && npm run dev
web-build:
	cd apps/web && npm run build
web-lint:
	cd apps/web && npm run lint
gallery:
	./content/capture-gallery.sh $(or $(PORT),3000)

package: build
	./apps/mac/Scripts/package.sh
native-shots: build
	./content/capture-native.sh
