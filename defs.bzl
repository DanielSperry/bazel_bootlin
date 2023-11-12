"""
Defines a bootlin_toolchain rule to allow toolchain customization.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    "//toolchain:toolchain_info.bzl",
    "ALL_TOOLS",
    "TOOLCHAIN_INFO",
)

def _bootlin_toolchain_impl(rctx):
    architecture = rctx.attr.architecture
    libc_impl = rctx.attr.libc_impl
    buildroot_version = rctx.attr.buildroot_version

    platform_arch = architecture.replace("-", "_")

    files_workspace = "{}_files".format(rctx.attr.name)

    for tool in ALL_TOOLS:
        buildroot_tool = (
            "{}.br_real".format(tool) if tool in ["cpp", "gcc"] else tool
        )

        rctx.file(
            "tool_wrappers/{}".format(tool),
            content = """#!/bin/bash

br_tool_relpath="external/{files_workspace}/bin/{arch}-buildroot-linux-gnu-{br_tool}"

if [[ -f "$br_tool_relpath" ]]; then
  exec "$br_tool_relpath" "$@"
elif [[ ${{BASH_SOURCE[0]}} == "/"* ]]; then
  # Some consumers of `CcToolchainConfigInfo` (e.g. `cmake` from rules_foreign_cc)
  # change CWD and call $CC (this script) with its absolute path.
  # the execroot (i.e. `cmake` from `rules_foreign_cc`) and call CC . For cases
  # like this, we try to find the "buildroot_tool" relative to this script.
  #
  # For more information, see
  # https://github.com/grailbio/bazel-toolchain/blob/master/toolchain/cc_wrapper.sh.tpl

  # This script is at _execroot_/external/_files_workspace_/tool_wrappers/*
  execroot_dir="${{BASH_SOURCE[0]%/*/*/*/*}}"
  tool="${{execroot_dir}}/${{br_tool_relpath}}"
  exec "$tool" "$@"
else
  echo >&2 "ERROR: could not find {br_tool}; PWD=\"${{PWD}}\"; PATH=\"${{PATH}}\"."
  exit 5
fi
""".format(
                files_workspace = files_workspace,
                arch = platform_arch,
                br_tool = buildroot_tool,
            ),
        )

    as_string = lambda args: (
        "[{}]".format(", ".join(
            [
                "'{}'".format(arg)
                for arg in args
            ],
        ))
    )

    bazel_output_base = str(rctx.path(".")).removesuffix("/external/{}".format(rctx.attr.name))
    template = Label("//toolchain:BUILD.toolchain.tpl")

    rctx.template(
        "BUILD.bazel",
        template,
        {
            "{bazel_output_base}": bazel_output_base,
            "{bootlin_workspace}": template.workspace_name,
            "{identifier}": rctx.attr.identifier,
            "{toolchain_files_workspace}": files_workspace,
            "{target_arch}": architecture,
            "{libc_impl}": libc_impl,
            "{buildroot_version}": buildroot_version,
            "{extra_cxx_flags}": as_string(rctx.attr.extra_cxx_flags),
            "{extra_link_flags}": as_string(rctx.attr.extra_link_flags),
            "{gcc_version}": rctx.attr.gcc_version or TOOLCHAIN_INFO[rctx.attr.identifier]["gcc_version"],
            "{libc_version}": rctx.attr.libc_version or TOOLCHAIN_INFO[rctx.attr.identifier]["libc_version"],
        },
    )

    rctx.file(
        "sysroot_path.bzl",
        content = """
SYSROOT_PATH="{bazel_output_base}/external/{files_workspace}/x86_64-buildroot-linux-gnu/sysroot"
""".format(
            bazel_output_base = bazel_output_base,
            files_workspace = files_workspace,
        ),
        executable = False,
    )

_bootlin_toolchain = repository_rule(
    attrs = {
        "identifier": attr.string(
            mandatory = True,
            doc = "bootlin identifier, key into TOOLCHAIN_INFO",
        ),
        "architecture": attr.string(
            mandatory = True,
        ),
        "libc_impl": attr.string(
            mandatory = True,
        ),
        "buildroot_version": attr.string(
            mandatory = True,
        ),
        "extra_cxx_flags": attr.string_list(
            default = [],
            doc = "Additional flags used for C++ compile actions.",
        ),
        "extra_link_flags": attr.string_list(
            default = [],
            doc = "Additional flags used for link actions.",
        ),
        "sha256" : attr.string(
            default = "",
            doc = "SHA256 of the toolchain archive. Can be omitted if the toolchain is known by bazel_bootlin.",
        ),
        "gcc_version" : attr.string(
            default = "",
            doc = "gcc version. Can be omitted if the toolchain is known by bazel_bootlin.",
        ),
        "libc_version" : attr.string(
            default = "",
            doc = "libc version. Can be omitted if the toolchain is known by bazel_bootlin.",
        ),
    },
    local = True,
    configure = True,
    implementation = _bootlin_toolchain_impl,
)

def bootlin_toolchain(**kwargs):
    # Handle microarchitecture suffixes.
    microarch = kwargs["architecture"]
    macroarch = "x86-64" if microarch.startswith("x86-64") else microarch.split('-')[0]
    sha256 = kwargs.get("sha256", None)

    identifier = "--".join([
        microarch,
        kwargs["libc_impl"],
        kwargs["buildroot_version"],
    ])
    kwargs["architecture"] = macroarch

    files_workspace = "{}_files".format(kwargs["name"])
    http_archive(
        name = files_workspace,
        build_file_content = """
filegroup(
    name = "{files_workspace}",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
""".format(files_workspace = files_workspace),
        url = ("https://toolchains.bootlin.com/downloads/releases/toolchains/" +
               "{arch}/tarballs/{iden}.tar.bz2").format(
            arch = microarch,
            iden = identifier,
        ),
        patch_cmds = [
            """
echo 'filegroup(' >> {arch}-buildroot-linux-gnu/sysroot/BUILD.bazel
echo '    name = "sysroot",' >> {arch}-buildroot-linux-gnu/sysroot/BUILD.bazel
echo '    srcs = glob(["**"]),' >> {arch}-buildroot-linux-gnu/sysroot/BUILD.bazel
echo '    visibility = ["//visibility:public"],' >> {arch}-buildroot-linux-gnu/sysroot/BUILD.bazel
echo ')' >> {arch}-buildroot-linux-gnu/sysroot/BUILD.bazel
""".format(arch = macroarch.replace("-", "_")),
        ],
        sha256 = sha256 or TOOLCHAIN_INFO[identifier]["sha256"],
        strip_prefix = identifier,
    )

    _bootlin_toolchain(identifier = identifier, **kwargs)
