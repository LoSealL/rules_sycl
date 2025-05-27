"""Defines all providers that are used in this repo."""

sycl_archs = [
    "cpu",
    "cuda",
    "rocm",
    "rpl-s",
    "rpl-p",
    "lnl-m",
]

Stage2ArchInfo = provider(
    """Provides the information of how the stage 2 compilation is carried out.

One and only one of `virtual`, `gpu` and `lto` must be set to True. For example, if `arch` is set to `80` and `virtual` is `True`, then a
ptx embedding process is carried out for `compute_80`. Multiple `Stage2ArchInfo` can be used for specifying how a stage 1 result is
transformed into its final form.""",
    fields = {
        "arch": "str, arch number",
        "virtual": "bool, use virtual arch, default False",
        "gpu": "bool, use gpu arch, default False",
        "lto": "bool, use lto, default False",
    },
)

ArchSpecInfo = provider(
    """Provides the information of how [GPU compilation](https://docs.nvidia.com/sycl/sycl-compiler-driver-nvcc/index.html#gpu-compilation)
is carried out of a single virtual architecture.""",
    fields = {
        "stage1_arch": "A virtual architecture, str, arch number only",
        "stage2_archs": "A list of virtual or gpu architecture, list of Stage2ArchInfo",
    },
)

SyclArchsInfo = provider(
    """Provides a list of SYCL archs to compile for.

Read the whole [Chapter 5 of SYCL Compiler Driver NVCC Reference Guide](https://docs.nvidia.com/sycl/sycl-compiler-driver-nvcc/index.html#gpu-compilation)
if more detail is needed.""",
    fields = {
        "arch_specs": "A list of ArchSpecInfo",
    },
)

SyclInfo = provider(
    """Provides sycl build artifacts that can be consumed by device linking or linking process.

This provider is analog to [CcInfo](https://bazel.build/rules/lib/CcInfo) but only contains necessary information for
linking in a flat structure. Objects are grouped by direct and transitive, because we have no way to split them again
if merged a single depset.
""",
    fields = {
        "defines": "A depset of strings. It is used for the compilation during device linking.",
        # direct only:
        "objects": "A depset of objects. Direct artifacts of the rule.",  # but not rdc and pic
        # transitive archive only (sycl_objects):
        "archive_objects": "A depset of rdc objects. sycl_objects only. Gathered from the transitive dependencies for archiving.",
    },
)

SyclToolkitInfo = provider(
    """Provides the information of SYCL Toolkit.""",
    fields = {
        "path": "string of path to sycl toolkit root",
        "version": "int of the sycl toolkit version, e.g, 2025.1",
        "icx": "File to the icx executable",
        "ocloc": "File to the ocloc executable",
    },
)

SyclToolchainConfigInfo = provider(
    """Provides the information of what the toolchain is and how the toolchain is configured.""",
    fields = {
        "action_configs": "A list of action_configs.",
        "artifact_name_patterns": "A list of artifact_name_patterns.",
        "sycl_toolkit": "A target that provides a `SyclToolkitInfo`",
        "features": "A list of features.",
        "toolchain_identifier": "icx",
    },
)
