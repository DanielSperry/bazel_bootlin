load(
    "@bazel_tools//tools/cpp:unix_cc_toolchain_config.bzl",
    unix_cc_toolchain_config = "cc_toolchain_config",
)
load("//toolchain:toolchain_info.bzl", "ALL_TOOLS", "TOOLCHAIN_INFO")

def cc_toolchain_config(
        name,
        identifier,
        target_arch,
        libc_impl,
        buildroot_version,
        toolchain_files_workspace,
        bazel_output_base,
        extra_cxx_flags,
        extra_link_flags,
        gcc_version,
        libc_version):
    target_arch_lower = target_arch.replace("-", "_")
    buildroot = "{}-buildroot-linux-gnu".format(
        target_arch_lower,
    )
    gcc_version = gcc_version or TOOLCHAIN_INFO[identifier]["gcc_version"]
    libc_version = libc_version or TOOLCHAIN_INFO[identifier]["libc_version"]

    # https://bazel.build/versions/6.0.0/rules/lib/cc_common#create_cc_toolchain_config_info
    host_system_name = "{}-linux".format(target_arch_lower)
    toolchain_identifier = "bootlin-gcc-{}-linux".format(target_arch_lower)
    target_system_name = "{}-linux-gnu".format(target_arch_lower)
    target_cpu = target_arch
    compiler = "gcc"
    target_libc = libc_version.split("_")[0]
    abi_version = "gcc_{}".format(gcc_version)
    abi_libc_version = libc_version

    sysroot_path = "{output_base}/external/{workspace}/{buildroot}/sysroot".format(
        output_base = bazel_output_base,
        workspace = toolchain_files_workspace,
        buildroot = buildroot,
    )

    # Unfiltered compiler flags; these are placed at the end of the command
    # line, so take precendence over any user supplied flags through --copts or
    # such.
    unfiltered_compile_flags = [
        # Do not resolve our symlinked resource prefixes to real paths.
        "-no-canonical-prefixes",
        "-fno-canonical-system-headers",
        # Reproducibility
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
    ]

    # Default compiler flags:
    compile_flags = [
        # Security
        "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        # Diagnostics
        "-fdiagnostics-color",
    ]

    # Default linker flags:
    link_flags = [
        # Flags copied from local_config_cc
        "-Wl,-no-as-needed",
        "-Wl,-z,relro,-z,now",
        "-pass-exit-codes",
        # Use libraries from toolchain sysroot
        "-Wl,--rpath={sysroot}/lib".format(sysroot = sysroot_path),
        "-Wl,--rpath={sysroot}/usr/lib".format(sysroot = sysroot_path),
        "-Wl,--rpath={sysroot}/../lib64".format(sysroot = sysroot_path),
        "-Wl,--dynamic-linker={sysroot}/lib/ld-linux-{arch}.so.2".format(
            sysroot = sysroot_path,
            arch = target_arch,
        ),
    ]

    # Flags related to C++ standard.
    cxx_flags = ["-std=c++20"]

    # Similar to link_flags, but placed later in the command line such that
    # unused symbols are not stripped.
    # The linker has no way of knowing if there are C++ objects; so we
    # always link C++ libraries.
    link_libs = [
        "-lstdc++",
        "-lm",
    ]

    # Debug flags
    dbg_compile_flags = ["-g"]

    # Opt flags
    opt_compile_flags = [
        "-g0",
        "-O2",
        "-D_FORTIFY_SOURCE=1",
        "-DNDEBUG",
        "-ffunction-sections",
        "-fdata-sections",
    ]
    opt_link_flags = ["-Wl,--gc-sections"]

    # Coverage flags:
    coverage_compile_flags = ["--coverage"]
    coverage_link_flags = ["--coverage"]

    # C++ built-in include directories:
    # https://stackoverflow.com/questions/4980819/what-are-the-gcc-default-include-directories
    #
    # https://stackoverflow.com/questions/72078638/how-to-pass-include-directories-from-package-imported-in-workspace-to-cxx-builti
    # https://github.com/bazelbuild/bazel/issues/4605

    cxx_builtin_include_directories = [
        "%package(@{workspace}//{path})%".format(
            workspace = toolchain_files_workspace,
            path = path,
        ).format(
            gcc_version = gcc_version,
            buildroot = buildroot,
        )
        for path in [
            "{buildroot}/include/c++/{gcc_version}",
            "{buildroot}/include/c++/{gcc_version}/{buildroot}",
            "{buildroot}/include/c++/{gcc_version}/backward",
            "lib/gcc/{buildroot}/{gcc_version}/include",
            "lib/gcc/{buildroot}/{gcc_version}/include-fixed",
        ]
    ]

    # The %package()% syntax doesn't seem to work for these directories
    cxx_builtin_include_directories.extend([
        path.format(
            output_base = bazel_output_base,
            workspace = toolchain_files_workspace,
            buildroot = buildroot,
        )
        for path in [
            "{output_base}/external/{workspace}/{buildroot}/include",
            "{output_base}/external/{workspace}/{buildroot}/sysroot/usr/include",
        ]
    ])

    tool_paths = {
        tool: "tool_wrappers/{}".format(tool)
        for tool in ALL_TOOLS
    }

    tool_paths["llvm-cov"] = "None"
    tool_paths["llvm-profdata"] = "None"

    unix_cc_toolchain_config(
        name = name,
        cpu = target_cpu,
        compiler = compiler,
        toolchain_identifier = toolchain_identifier,
        host_system_name = host_system_name,
        target_system_name = target_system_name,
        target_libc = target_libc,
        abi_version = abi_version,
        abi_libc_version = abi_libc_version,
        cxx_builtin_include_directories = cxx_builtin_include_directories,
        tool_paths = tool_paths,
        compile_flags = compile_flags,
        dbg_compile_flags = dbg_compile_flags,
        opt_compile_flags = opt_compile_flags,
        cxx_flags = cxx_flags + extra_cxx_flags,
        link_flags = link_flags + extra_link_flags,
        link_libs = link_libs,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        builtin_sysroot = sysroot_path,
        supports_start_end_lib = False,
    )
