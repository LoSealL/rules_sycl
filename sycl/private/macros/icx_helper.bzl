load("//sycl/private:defs.bzl", "requires_sycl")

def _uniq(iterable):
    """Remove duplicates from a list."""

    unique_elements = {element: None for element in iterable}
    return unique_elements.keys()

def _default_extra_features():
    return []

def _default_disabled_features():
    _features = [
        "default_link_flags",
        "dynamic_link_msvcrt",
        "linker_subsystem_flag",
    ]
    return ["-" + i for i in _uniq(_features)]

def icx_attrs(**attrs):
    """A macro to create a dict with icx toolchain attributes.

    It adds "icx" feature and `requires_sycl()` to the target_compatible_with.

    Args:
        **attrs: additional keyword arguments passed to the dict.
    """
    features = attrs.pop("features", []) + _default_extra_features() + _default_disabled_features()
    target_compatible_with = attrs.pop("target_compatible_with", []) + requires_sycl()

    return struct(
        features = _uniq(features),
        target_compatible_with = _uniq(target_compatible_with),
    )
