"""Shared macros for Swift modules in this app."""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

def fp_swift_library(name, srcs = None, deps = [], data = [], visibility = None, testonly = False):
    """A Swift 6 module named after its target.

    Every module in ios/ uses this so language mode and naming stay uniform.
    Tagged manual so `bazel build //ios/...` builds them only through the app or tests.

    Args:
      name: target and module name.
      srcs: Swift sources; defaults to every .swift file in the package.
      deps: other modules this one imports.
      visibility: Bazel visibility (who may depend on this module).
      testonly: True for test-only helper modules.
      data: resource bundles (apple_resource_bundle) this module needs at runtime.
    """
    swift_library(
        name = name,
        srcs = srcs if srcs != None else native.glob(["*.swift"]),
        module_name = name,
        copts = ["-swift-version", "6"],
        tags = ["manual"],
        deps = deps,
        data = data,
        visibility = visibility,
        testonly = testonly,
    )
