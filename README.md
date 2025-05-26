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
bazel_dep(name = "rules_sycl", version = "0.2.1")

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
- `sycl_objects`: If you don't understand what _device link_ means, you must never use it. This rule produces incomplete
  object files that can only be consumed by `sycl_library`. It is created for relocatable device code and device link
  time optimization source files.

### Flags

Some flags are defined in [sycl/BUILD.bazel](sycl/BUILD.bazel). To use them, for example:

```
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

#### Available flags

- `@rules_sycl//sycl:enable`

  Enable or disable all rules_sycl related rules. When disabled, the detected sycl toolchains will also be disabled to avoid potential human error.
  By default, rules_sycl rules are enabled. See `examples/if_sycl` for how to support both sycl-enabled and sycl-free builds.

- `@rules_sycl//sycl:archs`

  Select the sycl archs to support. See [sycl_archs specification DSL grammar](https://github.com/loseall/rules_sycl/blob/5633f0c0f7/sycl/private/rules/flags.bzl#L14-L44).

- `@rules_sycl//sycl:copts`

  Add the copts to all sycl compile actions.

- `@rules_sycl//sycl:host_copts`

  Add the copts to the host compiler.

## Examples

Checkout the examples to see if it fits your needs.

See [examples](./examples) for basic usage.

## Known issue

Sometimes the following error occurs:

```
cc1plus: fatal error: /tmp/tmpxft_00000002_00000019-2.cpp: No such file or directory
```

The problem is caused by nvcc use PID to determine temporary file name, and with `--spawn_strategy linux-sandbox` which is the default strategy on Linux, the PIDs nvcc sees are all very small numbers, say 2~4 due to sandboxing. `linux-sandbox` is not hermetic because [it mounts root into the sandbox](https://docs.bazel.build/versions/main/command-line-reference.html#flag--experimental_use_hermetic_linux_sandbox), thus, `/tmp` is shared between sandboxes, which is causing name conflict under high parallelism. Similar problem has been reported at [nvidia forums](https://forums.developer.nvidia.com/t/avoid-generating-temp-files-in-tmp-while-nvcc-compiling/197657/10).

To avoid it:

- Update to Bazel 7 where `--incompatible_sandbox_hermetic_tmp` is enabled by default.
- Use `--spawn_strategy local` should eliminate the case because it will let nvcc sees the true PIDs.
- Use `--experimental_use_hermetic_linux_sandbox` should eliminate the case because it will avoid the sharing of `/tmp`.
- Add `-objtemp` option to the command should reduce the case from happening.
