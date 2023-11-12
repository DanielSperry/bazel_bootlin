# RISC-V 64 Toolchain

This example cross-compiles a simple "Hello World" program for RISC-V 64 architecture on a x86_64 Linux.

To build the example, run in a x86-64 Linux environment:

```Shell
bazel build //hello

# check the binary's platform
file bazel-bin/hello/hello

# Expected output: 
# bazel-bin/hello/hello: ELF 64-bit LSB executable, UCB RISC-V, double-float ABI,
# version 1 (SYSV), statically linked, for GNU/Linux 4.15.0, not stripped
```

## How it works
### `.bazelrc`

The file `.bazelrc` Contains default bazel arguments defining the platform, enabling toolchain resolution, and disabling the local toolchain.

```Shell
# enables the toolchain resolution logic.
build --incompatible_enable_cc_toolchain_resolution
# ensures the local toolchain is not used.
build --action_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1
# defines the platform to be used
build --platforms=//platforms:riscv64_linux
```

The last line specifying the platform can be ommited but then the platform must be specified on the command line:

```
bazel build --platforms=//platforms:riscv64_linux //hello
```

### Platforms directory

Contains the platform definitions for this project. Usually you need your own platform deffinitions. See [the bazel docummentation](https://bazel.build/extending/platforms) for details.






