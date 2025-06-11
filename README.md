# SYCL rules for [Bazel](https://bazel.build)

This repository contains [Starlark](https://github.com/bazelbuild/starlark) implementation of [SYCL](https://www.khronos.org/sycl/) rules in Bazel.

These rules provide some macros and rules that make it easier to build SYCL with Bazel.

## Getting Started

### Traditional WORKSPACE approach

Add the following to your `WORKSPACE` file and replace the placeholders with actual values.

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_sycl",
    sha256 = "{sha256_to_replace}",
    strip_prefix = "rules_sycl-{git_commit_hash}",
    urls = ["https://github.com/loseall/rules_sycl/archive/{git_commit_hash}.tar.gz"],
)
load("@rules_sycl//sycl:repositories.bzl", "rules_sycl_dependencies", "rules_sycl_toolchains")
rules_sycl_dependencies()
rules_sycl_toolchains(register_toolchains = True)
```

**NOTE**: `rules_sycl_toolchains` implicitly calls to `register_detected_sycl_toolchains`, and the use of
`register_detected_sycl_toolchains` depends on the environment variable `CMPLR_ROOT`. You must also ensure the
host compiler is available. On Windows, this means that you will also need to set the environment variable
`BAZEL_VC` properly (mostly not needed if you installed Visual Studio in default location).

[`detect_sycl_toolkit`](https://github.com/loseall/rules_sycl/blob/5633f0c0f7/sycl/private/repositories.bzl#L28-L58) determains how the toolchains are detected.

### Bzlmod

Add the following to your `MODULE.bazel` file and replace the placeholders with actual values.

```starlark
bazel_dep(name = "rules_sycl", version = "0.0.0")

# pick a specific version (this is optional an can be skipped)
archive_override(
    module_name = "rules_sycl",
    integrity = "{SRI value}",  # see https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity
    url = "https://github.com/loseall/rules_sycl/archive/{git_commit_hash}.tar.gz",
    strip_prefix = "rules_sycl-{git_commit_hash}",
)

sycl = use_extension("@rules_sycl//sycl:extensions.bzl", "toolchain")
sycl.toolkit(
    name = "sycl",
    toolkit_path = "",
)
use_repo(sycl, "sycl")
```

### Rules

- `sycl_library`: Can be used to compile and create static library for SYCL kernel code. The resulting targets can be
  consumed by [C/C++ Rules](https://bazel.build/reference/be/c-cpp#rules).
- `sycl_binary`/`sycl_test`: Can be used to compile and create executable or shared library for SYCL kernel code.
- `icx_cc_library`: Can be used to compile and create static library for DPC++ code (without SYCL runtime involved). The resulting targets can be consumed by [C/C++ Rules](https://bazel.build/reference/be/c-cpp#rules).
- `icx_cc_binary`/`icx_cc_test`: Can be used to compile and create executable or shared library for DPC++ code (without SYCL runtime involved).

### Flags

Some flags are defined in [sycl/BUILD.bazel](sycl/BUILD.bazel). To use them, for example:

```
# not implemented yet!
bazel build --@rules_sycl//sycl:archs=rpl-p
```

In `.bazelrc` file, you can define a shortcut alias for the flag, for example:

```
# Convenient flag shortcuts.
build --flag_alias=sycl_archs=@rules_sycl//sycl:archs
```

and then you can use it as following:

```
bazel build --sycl_archs=rpl-p
```


## Examples

Checkout the examples to see if it fits your needs.

See [tests](./tests) for basic usage.

## Known issue
