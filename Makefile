# =============================================================================
# Project constants
# =============================================================================
IOS_BAZEL   := bazel --bazelrc=.bazelrc --bazelrc=ios/.bazelrc
APP_NAME    := FamilyPlanner
BUNDLE_ID   := io.github.foxyberry.familyplanner
APP_TARGET  := //ios:$(APP_NAME)

# Simulator config — override via CLI:
#   make run SIM_DEVICE="iPad Pro 11-inch (M5)" SIM_OS=26.5
SIM_DEVICE ?= iPad Pro 13-inch (M5)
SIM_OS     ?= 26.5
# Debug builds start the app clock elsewhere (time machine): make run NOW=2026-11-09T07:30 SPEED=60
LAUNCH_ARGS = $(if $(NOW),-fpNow $(NOW)) $(if $(SPEED),-fpSpeed $(SPEED)) $(if $(GRID),-fpGrid)
# OPEN=missions opens a screen deep link (familyplanner://missions) on launch.
OPEN_URL = $(if $(OPEN),--payload-url familyplanner://$(OPEN))
SIMULATOR   = $(shell xcrun simctl list devices "iOS $(SIM_OS)" available -j \
                | python3 -c "import sys,json; devs=[d for ds in json.load(sys.stdin)['devices'].values() for d in ds if '$(SIM_DEVICE)' == d['name']]; print(devs[0]['udid'] if devs else '')" 2>/dev/null)

.PHONY: build run device test test-one snapshots snapshots-record sim-stop stop-dev-sims art art-private xcodeproj clean clean-expunge fmt lint \
        check-prereqs setup setup-ios

# =============================================================================
# iOS
# =============================================================================

build:
	$(IOS_BAZEL) build $(APP_TARGET)

# Build first, then boot the simulator, so Bazel and the Simulator never compete
# for memory at the same time (8 GB Mac). Tests leave their own BAZEL_TEST_* simulator
# running, so shut everything down first and address the dev simulator by its UDID.
run: build
	@APP=$$(find bazel-bin/ios -name "$(APP_NAME).app" -type d | head -1) && \
	xcrun simctl shutdown all 2>/dev/null; \
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true && \
	open -a Simulator && \
	xcrun simctl install "$(SIMULATOR)" "$$APP" && \
	xcrun simctl launch --terminate-running-process "$(SIMULATOR)" $(BUNDLE_ID) $(LAUNCH_ARGS)

# Build, sign and install on a real iPad, by cable or over the same Wi-Fi once it has been
# paired by cable. With a free Apple ID the
# profile lasts 7 days: run this again to renew it (installing over keeps the app's data).
# The ipa stores every file at 1980-01-01 (deterministic builds) and devicectl's incremental
# install skips files whose size and time match, so a same-size new binary never reached the
# iPad. Touching the unpacked app makes every install copy everything.
device:
	@UDID=$$(scripts/connected-ipad.sh) && \
	scripts/device-profile.sh $(BUNDLE_ID) "$$UDID" && \
	$(IOS_BAZEL) build $(APP_TARGET) --config=device && \
	rm -rf bazel-device && mkdir bazel-device && \
	unzip -q bazel-bin/ios/$(APP_NAME).ipa -d bazel-device && \
	find bazel-device -exec touch {} + && \
	xcrun devicectl device install app --device "$$UDID" bazel-device/Payload/$(APP_NAME).app && \
	xcrun devicectl device process launch --terminate-existing --device "$$UDID" $(OPEN_URL) $(BUNDLE_ID) $(LAUNCH_ARGS) && \
	scripts/device-check.sh $(APP_NAME) bazel-device/Payload/$(APP_NAME).app/$(APP_NAME)

# The shared xctestrun runner (//ios:test_runner) picks the simulator from these flags.
# Failed snapshots leave their new picture in the git-ignored __Diffs__ folder (local runs
# only: CI does not set SNAPSHOT_ARTIFACTS, keeps no artifacts and logs one line per failure).
SNAPSHOT_ENV := $(if $(CI),,SNAPSHOT_ARTIFACTS="$(CURDIR)/ios/DesignSystem/SnapshotTests/__Diffs__")

# Tests reuse their own BAZEL_TEST_<device>_<os> simulator (//ios:test_runner) and leave it
# booted, so the next run skips a 15-20 s boot. Any other booted simulator (the dev one from
# `make run`, or a test one for another SIM_DEVICE/SIM_OS) makes tests time out or fail to
# install and costs memory, so it is shut down first.
# `make sim-stop` gives the memory back when you are done testing.
BOOTED_DEV_SIMS = $(shell xcrun simctl list devices booted -j 2>/dev/null \
                    | python3 -c "import sys,json; print(' '.join(d['udid'] for ds in json.load(sys.stdin)['devices'].values() for d in ds if d['name'] != 'BAZEL_TEST_$(SIM_DEVICE)_$(SIM_OS)'))" 2>/dev/null)
stop-dev-sims:
	@for udid in $(BOOTED_DEV_SIMS); do echo "shutting down simulator $$udid"; xcrun simctl shutdown "$$udid"; done

# Every test except the snapshot pictures (tag "snapshot"); CI runs the same set.
# Extra Bazel flags: make test TEST_ARGS=--nocache_test_results (re-runs every test).
# Run `make snapshots` whenever you change DesignSystem, KitArt or a screen.
test: stop-dev-sims
	$(IOS_BAZEL) test //ios/... --test_tag_filters=-snapshot $(TEST_ARGS) \
	  --ios_simulator_device="$(SIM_DEVICE)" \
	  --ios_simulator_version="$(SIM_OS)"

# One test target with the same flags as `make test` (keeps Bazel's caches warm):
#   make test-one TARGET=//ios/AppCore/Tests:AppCoreTests
test-one: stop-dev-sims
	@[ -n "$(TARGET)" ] || { echo "usage: make test-one TARGET=//ios/<Pkg>/Tests:<Target>"; exit 2; }
	$(SNAPSHOT_ENV) $(IOS_BAZEL) test $(TARGET) $(TEST_ARGS) \
	  --ios_simulator_device="$(SIM_DEVICE)" \
	  --ios_simulator_version="$(SIM_OS)"

# The snapshot pictures only: compares every part with its committed baseline.
SNAPSHOT_TARGET := //ios/DesignSystem/SnapshotTests:ComponentSnapshotTests
snapshots: stop-dev-sims
	$(SNAPSHOT_ENV) $(IOS_BAZEL) test $(SNAPSHOT_TARGET) $(TEST_ARGS) \
	  --ios_simulator_device="$(SIM_DEVICE)" \
	  --ios_simulator_version="$(SIM_OS)"

# Re-record the design system snapshot baselines into the source tree (the run itself fails:
# recording is not a pass). Compare the new pictures with the design boards before committing.
snapshots-record: stop-dev-sims
	SNAPSHOT_RECORD_DIR="$(CURDIR)/ios/DesignSystem/SnapshotTests/__Snapshots__" \
	$(IOS_BAZEL) test $(SNAPSHOT_TARGET) --nocache_test_results \
	  --ios_simulator_device="$(SIM_DEVICE)" \
	  --ios_simulator_version="$(SIM_OS)" || true
	@ls ios/DesignSystem/SnapshotTests/__Snapshots__ | wc -l | xargs echo "baselines:"

# Give the Simulator's memory back when you are done looking.
sim-stop:
	xcrun simctl shutdown all

# Generate an Xcode project only when Xcode is really needed.
xcodeproj:
	@if ! /opt/homebrew/bin/rsync --version >/dev/null 2>&1; then \
		echo "Installing GNU rsync (required for rules_xcodeproj on macOS 15.4+)..."; \
		brew install rsync; \
	fi
	$(IOS_BAZEL) run //ios:xcodeproj
	open ios/$(APP_NAME).xcodeproj

# =============================================================================
# Crayon kit pictures
# =============================================================================

# Regenerate the public crayon kit (v0 of every drawing slot). Same input, same files.
art:
	cd tools/crayon-art && npm ci --no-audit --no-fund && node kit.js . ../../ios/KitArt/Resources/KitArt.xcassets

# Build the local-only override catalog from git-ignored ios/KitArt/Private/<slot>.svg.
art-private:
	@./scripts/kitart-private.sh

# =============================================================================
# Shared
# =============================================================================

clean:
	bazel clean

clean-expunge:
	bazel clean --expunge

# Only tracked Bazel files: git-ignored folders (.build from SwiftPM indexing, bazel-*) hold
# other projects' BUILD files that are not ours to format.
BAZEL_FILES = git ls-files -z '*.bazel' '*.bzl' 'BUILD' 'WORKSPACE' 'MODULE.bazel'

fmt:
	$(BAZEL_FILES) | xargs -0 buildifier

lint:
	$(BAZEL_FILES) | xargs -0 buildifier --lint=warn --mode=check

# =============================================================================
# Setup
# =============================================================================

check-prereqs:
	@./scripts/check-prereqs.sh

setup-ios:
	@./scripts/setup-ios.sh $(APP_TARGET)

setup: check-prereqs setup-ios
	@[ -f user.bazelrc ] || { cp user.bazelrc.example user.bazelrc && echo "  created user.bazelrc"; }
	@[ -f .private-terms ] || { cp .private-terms.example .private-terms && echo "  created .private-terms (add your real private words)"; }
	@git config core.hooksPath .githooks && echo "  git hooks enabled (.githooks)"
	@command -v pymobiledevice3 >/dev/null || echo "  optional: uv tool install pymobiledevice3 (make device checks the iPad for crashes)"
	@echo "=== Setup complete: make build | make run | make test ==="
