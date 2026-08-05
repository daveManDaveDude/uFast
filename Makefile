SHELL := /bin/zsh
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
PROJECT := uFast.xcodeproj
SCHEME := uFast
DERIVED_DATA := .derived-data
SIMULATOR ?= platform=iOS Simulator,name=iPhone 17 Pro
UI_TEST_WORKERS ?= 4

.PHONY: bootstrap project build deploy-iphone deploy-iphones test test-unit test-ui testflight lint format verify-local-only clean

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
		-parallel-testing-enabled YES \
		-parallel-testing-worker-count "$(UI_TEST_WORKERS)" \
		-enableCodeCoverage NO \
		test

lint:
	swiftformat uFast uFastTests uFastUITests --lint --cache ignore
	DEVELOPER_DIR="$(DEVELOPER_DIR)" swiftlint lint --strict --no-cache

verify-local-only:
	./scripts/verify_local_only_release.sh

format:
	swiftformat uFast uFastTests uFastUITests --cache ignore

clean:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		clean
