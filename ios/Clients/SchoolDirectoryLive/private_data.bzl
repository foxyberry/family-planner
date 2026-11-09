"""Build-time check that the private school data is present.

The school and preschool lists are kept out of git (ios/Clients/SchoolDirectoryLive/Private/)
but every installable build must include them. This rule fails analysis with a clear message
when a required file is missing, unless the build says on purpose that it is a public build
(--config=public, which sets --define=public_build=1: CI and public clones only).
"""

def _private_data_check_impl(ctx):
    if not ctx.attr.public_build:
        present = [f.basename for f in ctx.files.srcs]
        missing = [name for name in ctx.attr.required if name not in present]
        if missing:
            fail(("School data missing: run make private\n" +
                  "  missing in ios/Clients/SchoolDirectoryLive/Private/: %s\n" +
                  "  (CI and public clones only: build with --config=public, or make ... PUBLIC_BUILD=1)") %
                 ", ".join(missing))

    # No outputs: as a `data` entry it adds nothing to the app bundle; analysing it is the check.
    return [DefaultInfo(files = depset())]

private_data_check = rule(
    implementation = _private_data_check_impl,
    attrs = {
        "public_build": attr.bool(doc = "True for CI and public clones: skip the check."),
        "required": attr.string_list(doc = "File names that must be present in srcs."),
        "srcs": attr.label_list(allow_files = [".json"]),
    },
    doc = "Fails the build when required private data files are absent (unless public_build).",
)
