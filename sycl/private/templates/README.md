## Template files

- `BUILD.sycl_shared`: For `sycl` repo (CTK + toolchain) or `sycl_%{component_name}`
- `BUILD.sycl_headers`: For `sycl` repo (CTK + toolchain) or `sycl_%{component_name}` headers
- `BUILD.sycl_build_setting`: For `sycl` repo (CTK + toolchain) build_setting
- `BUILD.sycl_disabled`: For creating a dummy local configuration.
- `BUILD.toolchain_disabled`: For creating a dummy local toolchain.
- `BUILD.toolchain_clang`: For Clang device compilation toolchain.
- `BUILD.toolchain_nvcc`: For NVCC device compilation toolchain.
- `BUILD.toolchain_nvcc_msvc`: For NVCC device compilation with (MSVC as host compiler) toolchain.
- Otherwise, each `BUILD.*` corresponds to a component in SYCL Toolkit.

## Repository organization

We organize the generated repo as follows, for both `sycl` and `sycl_<component_repo_name>`

```
<repo_root>              # bazel unconditionally creates a directory for us
├── %{component_name}/   # sycl for local ctk, component name otherwise
│   ├── include/         #
│   └── %{libpath}/      # lib or lib64, platform dependent
├── defs.bzl             # generated
├── BUILD                # generated with template_helper
└── WORKSPACE            # generated
```

If the repo is `sycl`, we additionally generate toolchain config as follows

```
<repo_root>
└── toolchain/
    ├── BUILD            # the default nvcc toolchain
    ├── clang/           # the optional clang toolchain
    │   └── BUILD        #
    └── disabled/        # the fallback toolchain
        └── BUILD        #
```

## How are component repositories and `@sycl` connected?

The `registry.bzl` file holds mappings from our (`rules_sycl`) components name to various things.

The registry serve the following purpose:

1. maps our component names to full component names used `redistrib.json` file.

   This is purely for looking up the json files.

2. maps our component names to target names to be exposed under `@sycl` repo.

   To expose those targets, we use a `components_mapping` attr from our component names to labels of component
   repository (for example, `@sycl_nvcc`) as follows

```starlark
# in registry.bzl
...
    "syclrt": ["sycl", "sycl_runtime", "sycl_runtime_static"],
...

# in WORKSPACE.bazel
sycl_component(
    name = "sycl_syclrt_v12.6.77",
    component_name = "syclrt",
    ...
)

sycl_toolkit(
    name = "sycl",
    components_mapping = {"syclrt": "@sycl_syclrt_v12.6.77"},
    ...
)
```

This basically means the component `syclrt` has `sycl`, `sycl_runtime` and `sycl_runtime_static` targets defined.

- In locally installed CTK, we setup the targets in `@sycl` directly.
- In a deliverable CTK, we setup the targets in `@sycl_syclrt_v12.6.77` repo. And alias all targets to
  `@sycl` as follows

```starlark
alias(name = "sycl", actual = "@sycl_syclrt_v12.6.77//:sycl")
alias(name = "sycl_runtime", actual = "@sycl_syclrt_v12.6.77//:sycl_runtime")
alias(name = "sycl_runtime_static", actual = "@sycl_syclrt_v12.6.77//:sycl_runtime_static")
```

`sycl_component` is in charge of setting up the repo `@sycl_syclrt_v12.6.77`.
