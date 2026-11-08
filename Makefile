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
LAUNCH_ARGS = $(if $(NOW),-fpNow $(NOW)) $(if $(SPEED),-fpSpeed $(SPEED))
SIMULATOR   = $(shell xcrun simctl list devices "iOS $(SIM_OS)" available -j \
                | python3 -c "import sys,json; devs=[d for ds in json.load(sys.stdin)['devices'].values() for d in ds if '$(SIM_DEVICE)' == d['name']]; print(devs[0]['udid'] if devs else '')" 2>/dev/null)

.PHONY: build run device test test-one snapshots-record sim-stop art art-private xcodeproj clean clean-expunge fmt lint \
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
device:
	@UDID=$$(scripts/connected-ipad.sh) && \
	scripts/device-profile.sh $(BUNDLE_ID) "$$UDID" && \
	$(IOS_BAZEL) build $(APP_TARGET) --config=device && \
	rm -rf bazel-device && mkdir bazel-device && \
	unzip -q bazel-bin/ios/$(APP_NAME).ipa -d bazel-device && \
	xcrun devicectl device install app --device "$$UDID" bazel-device/Payload/$(APP_NAME).app && \
	xcrun devicectl device process launch --terminate-existing --device "$$UDID" $(BUNDLE_ID) $(LAUNCH_ARGS)

# The shared xctestrun runner (//ios:test_runner) picks the simulator from these flags.
# Failed snapshots leave their new picture in the git-ignored __Diffs__ folder (local runs
# only: CI does not set SNAPSHOT_ARTIFACTS, keeps no artifacts and logs one line per failure).
SNAPSHOT_ENV := $(if $(CI),,SNAPSHOT_ARTIFACTS="$(CURDIR)/ios/DesignSystem/SnapshotTests/__Diffs__")
# CI skips snapshot tests (tag "snapshot") while the designs keep changing; local runs keep them.
TEST_FILTER  := $(if $(CI),--test_tag_filters=-snapshot,)

test:
	$(SNAPSHOT_ENV) $(IOS_BAZEL) test //ios/... $(TEST_FILTER) \
	  --ios_simulator_device="$(SIM_DEVICE)" \
	  --ios_simulator_version="$(SIM_OS)"

# One test target with the same flags as `make test` (keeps Bazel's caches warm):
#   make test-one TARGET=//ios/AppCore/Tests:AppCoreTests
test-one:
	@[ -n "$(TARGET)" ] || { echo "usage: make test-one TARGET=//ios/<Pkg>/Tests:<Target>"; exit 2; }
	$(SNAPSHOT_ENV) $(IOS_BAZEL) test $(TARGET) \
	  --ios_simulator_device="$(SIM_DEVICE)" \
	  --ios_simulator_version="$(SIM_OS)"

# Re-record the design system snapshot baselines into the source tree (the run itself fails:
# recording is not a pass). Compare the new pictures with the design boards before committing.
SNAPSHOT_TARGET := //ios/DesignSystem/SnapshotTests:ComponentSnapshotTests
snapshots-record:
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

fmt:
	buildifier -r .

lint:
	buildifier -r --lint=warn --mode=check .

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
	@echo "=== Setup complete: make build | make run | make test ==="
