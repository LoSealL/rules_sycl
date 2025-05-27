"""
Copyright (c) 2025 Wenyi Tang
Author: Wenyi Tang
E-mail: wenyitang@outlook.com

"""

load("//sycl/private:macros/icx_helper.bzl", "icx_attrs")

def icx_cc_binary(name, **kwargs):
    """A macro to create a cc_binary with icx toolchain.

    It adds "icx" feature and `requires_sycl()` to the target_compatible_with.

    Args:
        name: the name of the target.
        **kwargs: additional keyword arguments passed to cc_binary.
    """
    attr = icx_attrs(**kwargs)

    native.cc_binary(
        name = name,
        features = attr.features,
        target_compatible_with = attr.target_compatible_with,
        **kwargs
    )
