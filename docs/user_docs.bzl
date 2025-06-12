load(
    "@rules_sycl//sycl:defs.bzl",
    _icx_cc_binary = "icx_cc_binary",
    _icx_cc_library = "icx_cc_library",
    _icx_cc_test = "icx_cc_test",
    _requires_sycl = "requires_sycl",
    _spv_library = "spv_library",
    _sycl_binary = "sycl_binary",
    _sycl_library = "sycl_library",
    _sycl_test = "sycl_test",
)
load(
    "@rules_sycl//sycl:repositories.bzl",
    _rules_sycl_dependencies = "rules_sycl_dependencies",
    _rules_sycl_toolchains = "rules_sycl_toolchains",
    _sycl_toolkit = "sycl_toolkit",
)

sycl_library = _sycl_library
sycl_binary = _sycl_binary
sycl_test = _sycl_test
icx_cc_binary = _icx_cc_binary
icx_cc_library = _icx_cc_library
icx_cc_test = _icx_cc_test

spv_library = _spv_library
requires_sycl = _requires_sycl

sycl_toolkit = _sycl_toolkit
rules_sycl_dependencies = _rules_sycl_dependencies
rules_sycl_toolchains = _rules_sycl_toolchains
