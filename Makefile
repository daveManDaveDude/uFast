SHELL := /bin/zsh
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
PROJECT := uFast.xcodeproj
SCHEME := uFast
DERIVED_DATA := .derived-data
SIMULATOR ?= platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: bootstrap project build deploy-iphone deploy-iphones test test-unit test-ui testflight lint format clean

bootstrap:
	./scripts/bootstrap.sh

project:
	xcodegen generate

build: project
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO \
		build

deploy-iphone:
	./scripts/deploy_iphone.sh

deploy-iphones:
	./scripts/deploy_iphones.sh

testflight:
	./scripts/upload_testflight.sh

test: test-unit test-ui

test-unit: project
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination '$(SIMULATOR)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		-only-testing:uFastTests \
		test

test-ui: project
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination '$(SIMULATOR)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		-only-testing:uFastUITests \
		test

lint:
	swiftformat uFast uFastTests uFastUITests --lint --cache ignore
	DEVELOPER_DIR="$(DEVELOPER_DIR)" swiftlint lint --strict --no-cache

format:
	swiftformat uFast uFastTests uFastUITests --cache ignore

clean:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		clean
