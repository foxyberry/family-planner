# =============================================================================
# Project constants
# =============================================================================
IOS_BAZEL   := bazel --bazelrc=.bazelrc --bazelrc=ios/.bazelrc
APP_NAME    := FamilyPlanner
BUNDLE_ID   := com.example.familyplanner
APP_TARGET  := //ios:$(APP_NAME)

# Simulator config — override via CLI:
#   make run SIM_DEVICE="iPad Pro 11-inch (M5)" SIM_OS=26.5
SIM_DEVICE ?= iPad Pro 13-inch (M5)
SIM_OS     ?= 26.5
SIMULATOR   = $(shell xcrun simctl list devices "iOS $(SIM_OS)" available -j \
                | python3 -c "import sys,json; devs=[d for ds in json.load(sys.stdin)['devices'].values() for d in ds if '$(SIM_DEVICE)' == d['name']]; print(devs[0]['udid'] if devs else '')" 2>/dev/null)

.PHONY: build run test sim-stop xcodeproj clean clean-expunge fmt lint \
        check-prereqs setup setup-ios

# =============================================================================
# iOS
# =============================================================================

build:
	$(IOS_BAZEL) build $(APP_TARGET)

# Build first, then boot the simulator, so Bazel and the Simulator never compete
# for memory at the same time (8 GB Mac).
run: build
	@APP=$$(find bazel-bin/ios -name "$(APP_NAME).app" -type d | head -1) && \
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true && \
	open -a Simulator && \
	xcrun simctl install booted "$$APP" && \
	xcrun simctl launch booted $(BUNDLE_ID)

test:
	$(IOS_BAZEL) test //ios/... \
	  --test_arg=--device_type --test_arg="$(SIM_DEVICE)" \
	  --test_arg=--os_version --test_arg="$(SIM_OS)"

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
