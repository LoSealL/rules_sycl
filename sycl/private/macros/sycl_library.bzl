"""
Copyright (c) 2025 Wenyi Tang
Author: Wenyi Tang
E-mail: wenyitang@outlook.com

"""

load("//sycl/private:macros/icx_helper.bzl", "icx_attrs")

def sycl_library(name, **kwargs):
    """A macro to create a cc_library with icx toolchain.

    It adds "icx" feature and `requires_sycl()` to the target_compatible_with.

    Args:
        name: the name of the target.
        **kwargs: additional keyword arguments passed to cc_library.
    """
    attr = icx_attrs(**kwargs)
    deps = kwargs.pop("deps", [])
    deps.append("@sycl//:sycl_headers")

    native.cc_library(
        name = name,
        features = attr.features + ["sycl_compile_flag"],
        target_compatible_with = attr.target_compatible_with,
        deps = deps,
        **kwargs
    )
