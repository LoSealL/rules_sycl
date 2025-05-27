"""private"""

def requires_sycl():
    """Returns constraint_setting that is satisfied if:

    * rules are enabled and
    * a valid toolchain is configured.

    Add to 'target_compatible_with' attribute to mark a target incompatible when
    the conditions are not satisfied. Incompatible targets are excluded
    from bazel target wildcards and fail to build if requested explicitly.
    """
    return ["@sycl//toolchain:rules_are_enabled"]
