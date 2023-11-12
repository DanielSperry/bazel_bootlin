load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "hello",
    srcs = ["hello.c"],
    # using static linking to avoid the need for a runtime dependency on libc
    linkopts = ["-static"],
)
