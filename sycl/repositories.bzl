load(
    "//sycl/private:repositories.bzl",
    _default_components_mapping = "default_components_mapping",
    _rules_sycl_dependencies = "rules_sycl_dependencies",
    _rules_sycl_toolchains = "rules_sycl_toolchains",
    _sycl_toolkit = "sycl_toolkit",
)

# rules
sycl_toolkit = _sycl_toolkit

# macros
rules_sycl_dependencies = _rules_sycl_dependencies
rules_sycl_toolchains = _rules_sycl_toolchains
default_components_mapping = _default_components_mapping
