load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def rules_ocl_dependencies():
    """Populate the dependencies for rules_sycl. This will setup other bazel rules as workspace dependencies"""

    git_repository(
        name = "opencl_clhpp",
        remote = "https://github.com/KhronosGroup/OpenCL-CLHPP",
        commit = "2a608428f725cad7903ef55e1ce5b995895838f5",
        build_file_content = """
cc_library(
    name = "opencl_clhpp",
    hdrs = glob(["include/CL/*.hpp"]),
    includes = ["include"],
    visibility = ["//visibility:public"],
)
""",
    )

    git_repository(
        name = "opencl_headers",
        remote = "https://github.com/KhronosGroup/OpenCL-Headers",
        commit = "4ea6df132107e3b4b9407f903204b5522fdffcd6",
        build_file_content = """
cc_library(
    name = "opencl_headers",
    hdrs = glob(["CL/*.h"]),
    includes = ["CL", "."],
    visibility = ["//visibility:public"],
)
""",
    )

    git_repository(
        name = "opencl_icd_loader",
        remote = "https://github.com/KhronosGroup/OpenCL-ICD-Loader",
        commit = "5907ac1114079de4383cecddf1c8640e3f52f92b",
        build_file_content = """
# Bazel rules for OpenCL-ICD Loader

filegroup(
    name = "icd_loader_sources",
    srcs = [
        "loader/icd.c",
        "loader/icd.h",
        "loader/icd_dispatch.c",
        "loader/icd_dispatch.h",
        "loader/icd_dispatch_generated.c",
        "loader/icd_envvars.h",
        "loader/icd_platform.h",
        "loader/icd_version.h",
    ],
)

filegroup(
    name = "icd_loader_sources_win",
    srcs = [
        "loader/windows/adapter.h",
        "loader/windows/icd_windows.c",
        "loader/windows/icd_windows.h",
        "loader/windows/icd_windows_apppackage.c",
        "loader/windows/icd_windows_apppackage.h",
        "loader/windows/icd_windows_dxgk.c",
        "loader/windows/icd_windows_dxgk.h",
        "loader/windows/icd_windows_envvars.c",
        "loader/windows/icd_windows_hkr.c",
        "loader/windows/icd_windows_hkr.h",
    ],
)

filegroup(
    name = "icd_loader_sources_lin",
    srcs = [
        "loader/linux/icd_linux.c",
        "loader/linux/icd_linux_envvars.c",
    ],
)

genrule(
    name = "dummy_icd_cmake_config",
    outs = ["icd_cmake_config.h"],
    cmd = "touch $@",
    cmd_bat = "echo // Dummy file for CMake config > $@",
)

OPENCL_ICD_LOADER_SOURCES = [
    ":icd_loader_sources",
    ":dummy_icd_cmake_config",
] + select({
    "@platforms//os:windows": [":icd_loader_sources_win"],
    "//conditions:default": [":icd_loader_sources_lin"],
})

OPENCL_COMPILE_DEFINITIONS = [
    "CL_TARGET_OPENCL_VERSION=300",
    "CL_NO_NON_ICD_DISPATCH_EXTENSION_PROTOTYPES",
    "OPENCL_ICD_LOADER_VERSION_MAJOR=3",
    "OPENCL_ICD_LOADER_VERSION_MINOR=0",
    "OPENCL_ICD_LOADER_VERSION_REV=6",
    "CL_ENABLE_LAYERS",
]

cc_binary(
    name = "OpenCL",
    srcs = OPENCL_ICD_LOADER_SOURCES,
    additional_linker_inputs = ["loader/linux/icd_exports.map"],
    defines = OPENCL_COMPILE_DEFINITIONS,
    includes = ["loader"],
    linkopts = select({
        "@platforms//os:windows": [
            "/DEFAULTLIB:onecore.lib",
        ],
        "//conditions:default": [
            # "-Wl,--version-script",
            # "-Wl,loader/linux/icd_exports.map",
            "-ldl",
        ],
    }),
    linkshared = 1,
    visibility = ["//visibility:public"],
    win_def_file = "loader/windows/OpenCL.def",
    deps = ["@opencl_headers"],
)

cc_binary(
    name = "cllayerinfo",
    srcs = ["loader/cllayerinfo.c"] + OPENCL_ICD_LOADER_SOURCES,
    defines = ["CL_LAYER_INFO"] + OPENCL_COMPILE_DEFINITIONS,
    includes = ["loader"],
    linkopts = select({
        "@platforms//os:windows": [
            "/DEFAULTLIB:onecore.lib",
        ],
        "//conditions:default": [
            "-ldl",
            "-lpthread",
        ],
    }),
    deps = ["@opencl_headers"],
)


filegroup(
    name = "opencl_lib",
    srcs = [":OpenCL"],
    output_group = "interface_library",
    target_compatible_with = ["@platforms//os:windows"],
)

cc_import(
    name = "opencl_dll",
    interface_library = ":opencl_lib",
    shared_library = ":OpenCL",
    target_compatible_with = ["@platforms//os:windows"],
)

cc_import(
    name = "opencl_so",
    shared_library = ":OpenCL",
    target_compatible_with = ["@platforms//os:linux"],
)

cc_library(
    name = "opencl_icd_loader",
    visibility = ["//visibility:public"],
    deps = ["@opencl_headers"] + select({
        "@platforms//os:windows": [":opencl_dll"],
        "//conditions:default": [":opencl_so"],
    }),
)
""",
    )
