SHELL := /bin/zsh
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
PROJECT := uFast.xcodeproj
SCHEME := uFast
DERIVED_DATA := .derived-data
SIMULATOR ?= platform=iOS Simulator,name=iPhone 17 Pro
UI_TEST_WORKERS ?= 4
CODE_SIGNING_ALLOWED ?= NO

.PHONY: bootstrap project build deploy-iphone deploy-iphones test test-unit test-ui testflight release-gate verify-release-gate lint analyze format verify-local-only verify-diagnostics verify-document-index verify-binary-evidence verify-release-versions verify-ui-result verify-ui-verifier verify-agentic-config verify-architecture clean

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
		CODE_SIGNING_ALLOWED="$(CODE_SIGNING_ALLOWED)" \
		build

deploy-iphone:
	./scripts/deploy_iphone.sh

deploy-iphones:
	./scripts/deploy_iphones.sh

testflight:
	./scripts/upload_testflight.sh

release-gate:
	UI_XCRESULT="$(UI_XCRESULT)" python3 scripts/release_gate.py

verify-release-gate:
	python3 scripts/verify_entitlements.py --self-test
	python3 scripts/release_gate.py --self-test
	./scripts/upload_testflight.sh --self-test

test: test-unit test-ui

test-unit: project
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination '$(SIMULATOR)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		-only-testing:uFastTests \
		test
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "UFastCore" \
		-destination '$(SIMULATOR)' \
		-derivedDataPath "$(DERIVED_DATA)" \
		-only-testing:UFastCoreTests \
		test

test-ui: project
	DEVELOPER_DIR="$(DEVELOPER_DIR)" PROJECT="$(PROJECT)" SCHEME="$(SCHEME)" DERIVED_DATA="$(DERIVED_DATA)" SIMULATOR='$(SIMULATOR)' UI_TEST_WORKERS="$(UI_TEST_WORKERS)" UI_RESULTS_DIR="$(UI_RESULTS_DIR)" UI_RESULT_BUNDLE="$(UI_RESULT_BUNDLE)" UI_TEST_LOG="$(UI_TEST_LOG)" SOURCE_FREEZE_ID="$(SOURCE_FREEZE_ID)" zsh scripts/run_ui_tests.sh

lint: verify-architecture
	./scripts/count_swift_sources.sh "SwiftFormat" UFastCore UFastCoreTests uFast LockScreenShared LockScreenPrototype LockScreenWidget uFastTests uFastUITests
	swiftformat UFastCore UFastCoreTests uFast LockScreenShared LockScreenPrototype LockScreenWidget uFastTests uFastUITests --lint --cache ignore
	./scripts/count_swift_sources.sh "SwiftLint" UFastCore UFastCoreTests uFast LockScreenShared LockScreenPrototype LockScreenWidget uFastTests uFastUITests
	DEVELOPER_DIR="$(DEVELOPER_DIR)" swiftlint lint --strict --no-cache

analyze:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" ./scripts/analyze_swift.sh

verify-local-only:
	./scripts/verify_local_only_release.sh

verify-diagnostics:
	python3 scripts/check_diagnostic_privacy.py --self-test
	python3 scripts/check_diagnostic_privacy.py

verify-document-index:
	python3 scripts/check_document_index.py --self-test
	python3 scripts/check_document_index.py

verify-binary-evidence:
	python3 scripts/check_tracked_binary_evidence.py --self-test
	python3 scripts/check_tracked_binary_evidence.py

verify-release-versions: project
	./scripts/verify_release_versions.sh

verify-ui-result:
	@test -n "$(UI_XCRESULT)" || (echo "UI_XCRESULT must name an .xcresult bundle" >&2; exit 2)
	./scripts/verify_ui_xcresult.py "$(UI_XCRESULT)"

verify-ui-verifier:
	./scripts/verify_ui_xcresult.py --self-test

verify-agentic-config:
	python3 scripts/agentic_activity.py --self-test
	python3 scripts/verify_agentic_config.py
	zsh -n scripts/run_ui_tests.sh
	zsh scripts/run_ui_tests.sh --self-test

verify-architecture:
	python3 scripts/check_feature_architecture.py --self-test
	python3 scripts/check_feature_architecture.py

format:
	./scripts/count_swift_sources.sh "SwiftFormat" UFastCore UFastCoreTests uFast LockScreenShared LockScreenPrototype LockScreenWidget uFastTests uFastUITests
	swiftformat UFastCore UFastCoreTests uFast LockScreenShared LockScreenPrototype LockScreenWidget uFastTests uFastUITests --cache ignore

clean:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		clean
