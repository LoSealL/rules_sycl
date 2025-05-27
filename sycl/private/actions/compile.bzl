"""
Copyright (c) 2025 Wenyi Tang
Author: Wenyi Tang
E-mail: wenyitang@outlook.com

"""
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", CC_ACTION_NAMES = "ACTION_NAMES")
load("//sycl/private:action_names.bzl", "ACTION_NAMES")
load("//sycl/private:rules/common.bzl", "ALLOW_SYCL_SRCS")
load("//sycl/private:sycl_helper.bzl", "sycl_helper")

def compile(
        ctx,
        sycl_toolchain,
        cc_toolchain,
        srcs,
        common):
    """Perform SYCL compilation, return compiled object files.

    Notes:

    - If `rdc` is set to `True`, then an additional step of device link must be performed.
    - The rules should call this action only once in case srcs have non-unique basenames,
      say `foo/kernel.cu` and `bar/kernel.cu`.

    Args:
        ctx: A [context object](https://bazel.build/rules/lib/ctx).
        sycl_toolchain: A `platform_common.ToolchainInfo` of a sycl toolchain, Can be obtained with `find_sycl_toolchain(ctx)`.
        cc_toolchain: A `CcToolchainInfo`. Can be obtained with `find_cpp_toolchain(ctx)`.
        srcs: A list of `File`s to be compiled.
        common: A sycl common object. Can be obtained with `sycl_helper.create_common(ctx)`

    Returns:
        An compiled object `File`.
    """
    actions = ctx.actions
    cc_feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features + [
            "determinism",
            "compiler_param_file",
        ],
    )
    sycl_compiler = sycl_toolchain.compiler_executable
    artifact_category_name = sycl_helper.get_artifact_category_from_action(ACTION_NAMES.sycl_compile)

    basename_counter = {}
    src_and_indexed_basenames = []
    for src in srcs:
        # this also filter out all header files
        basename = sycl_helper.get_basename_without_ext(src.basename, ALLOW_SYCL_SRCS, fail_if_not_match = False)
        if not basename:
            continue
        basename_index = basename_counter.setdefault(basename, 0)
        basename_counter[basename] += 1
        src_and_indexed_basenames.append((src, basename, basename_index))

    ret = []
    for src, basename, basename_index in src_and_indexed_basenames:
        filename = sycl_helper.get_artifact_name(sycl_toolchain, artifact_category_name, basename)

        # Objects are placed in <_prefix>/<tgt_name>/<filename>.
        # For files with the same basename, say srcs = ["kernel.cu", "foo/kernel.cu", "bar/kernel.cu"], we get
        # <_prefix>/<tgt_name>/0/kernel.<ext>, <_prefix>/<tgt_name>/1/kernel.<ext>, <_prefix>/<tgt_name>/2/kernel.<ext>.
        # Otherwise, the index is not presented.
        if basename_counter[basename] > 1:
            filename = "{}/{}".format(basename_index, filename)
        obj_file = actions.declare_file("{}/{}".format(ctx.attr.name, filename))
        ret.append(obj_file)

        cc_compile_variables = cc_common.create_compile_variables(
            feature_configuration = cc_feature_configuration,
            cc_toolchain = cc_toolchain,
            source_file = src.path,
            output_file = obj_file.path,
            user_compile_flags = common.compile_flags,
            include_directories = depset(common.includes),
            quote_include_directories = depset(common.quote_includes),
            system_include_directories = depset(common.system_includes),
            preprocessor_defines = depset(common.local_defines + common.defines),
        )

        env = cc_common.get_environment_variables(
            feature_configuration = cc_feature_configuration,
            action_name = ACTION_NAMES.sycl_compile,
            variables = cc_compile_variables,
        )

        cmd = cc_common.get_memory_inefficient_command_line(
            feature_configuration = cc_feature_configuration,
            action_name = CC_ACTION_NAMES.cpp_compile,
            variables = cc_compile_variables,
        )

        args = actions.args()
        args.add_all(cmd)

        actions.run(
            executable = sycl_compiler,
            arguments = [args],
            outputs = [obj_file],
            inputs = depset([src], transitive = [common.headers, cc_toolchain.all_files, sycl_toolchain.all_files]),
            env = env,
            mnemonic = "SyclCompile",
            progress_message = "Compiling %s" % src.path,
        )
    return ret
