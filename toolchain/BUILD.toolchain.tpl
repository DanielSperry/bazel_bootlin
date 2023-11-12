# //:BUILD.bazel
load("@{bootlin_workspace}//toolchain:cc_toolchain_config.bzl", "cc_toolchain_config")

filegroup(name = "empty")

filegroup(
    name = "all_files",
    srcs = [
        "@{toolchain_files_workspace}",
    ] + glob(["tool_wrappers/**"]),
)

cc_toolchain_config(
    name = "toolchain_config",
    identifier = "{identifier}",
    target_arch = "{target_arch}",
    libc_impl = "{libc_impl}",
    buildroot_version = "{buildroot_version}",
    toolchain_files_workspace = "{toolchain_files_workspace}",
    bazel_output_base = "{bazel_output_base}",
    extra_cxx_flags = {extra_cxx_flags},
    extra_link_flags = {extra_link_flags},
    gcc_version = "{gcc_version}",
    libc_version = "{libc_version}",
)

cc_toolchain(
    name = "cc_toolchain",
    all_files = ":all_files",
    ar_files = ":all_files",
    compiler_files = ":all_files",
    dwp_files = ":empty",
    linker_files = ":all_files",
    objcopy_files = ":empty",
    strip_files = ":empty",
    toolchain_config = ":toolchain_config",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "toolchain",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:{}".format("{target_arch}".replace("-", "_")),
        "@platforms//os:linux",
    ],
    toolchain = "cc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    visibility = ["//visibility:public"],
)
