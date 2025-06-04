"""
Copyright (c) 2025 Wenyi Tang
Author: Wenyi Tang
E-mail: wenyitang@outlook.com

Generate AOT SPIR-V bytecode for target device.

Reference command line:
icpx -fsycl main.cc -fsycl-targets=spir64_gen -fsycl-device-only -fsycl-dump-device-code="." -o main.bc
# note -spirv-ext enables all Intel SPIR-V extensions
llvm-spirv main.bc -spirv-max-version="1.4" -spirv-debug-info-version=nonsemantic-shader-200 -spirv-allow-unknown-intrinsics="llvm.genx." -spirv-ext="-all,..."
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("//sycl/private:rules/common.bzl", "ALLOW_SYCL_SRCS", "create_common")

def _get_basename_without_ext(basename, allow_exts):
    for ext in sorted(allow_exts, key = len, reverse = True):
        if basename.endswith(ext):
            return basename[:-len(ext)]
    return None

def _impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features + ["sycl_compile_flag"],
        unsupported_features = ctx.disabled_features,
    )
    icx_tool = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_compile,
    )
    spv_tool = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = "sycl-spv-codegen",
    )

    src_files = []
    for src in ctx.attr.srcs:
        src_files.extend(src[DefaultInfo].files.to_list())

    common = create_common(ctx)

    basename_counter = {}
    src_and_indexed_basenames = []
    for src in src_files:
        # this also filter out all header files
        basename = _get_basename_without_ext(src.basename, ALLOW_SYCL_SRCS)
        if not basename:
            continue
        basename_index = basename_counter.setdefault(basename, 0)
        basename_counter[basename] += 1
        src_and_indexed_basenames.append((src, basename, basename_index))

    ret = []
    for src, basename, basename_index in src_and_indexed_basenames:
        filename = basename

        # Objects are placed in <_prefix>/<tgt_name>/<filename>.
        # For files with the same basename, say srcs = ["kernel.cu", "foo/kernel.cu", "bar/kernel.cu"], we get
        # <_prefix>/<tgt_name>/0/kernel.<ext>, <_prefix>/<tgt_name>/1/kernel.<ext>, <_prefix>/<tgt_name>/2/kernel.<ext>.
        # Otherwise, the index is not presented.
        if basename_counter[basename] > 1:
            filename = "{}/{}".format(basename_index, basename)
        bc_file = ctx.actions.declare_file("spv/{}/{}.bc".format(ctx.attr.name, filename))
        spv_file = ctx.actions.declare_file("spv/{}/{}.spv".format(ctx.attr.name, filename))
        ret.append(spv_file)
        vars = cc_common.create_compile_variables(
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            source_file = src.path,
            user_compile_flags = ctx.fragments.cpp.copts,
            include_directories = common.includes,
            quote_include_directories = common.quote_includes,
            system_include_directories = common.system_includes,
            preprocessor_defines = common.defines,
        )
        cmd = cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.cpp_compile,
            variables = vars,
        )
        env = cc_common.get_environment_variables(
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.cpp_compile,
            variables = vars,
        )

        args = ctx.actions.args()
        args.add_all(cmd)
        args.add("-fsycl-targets=spir64_gen")
        args.add("-fsycl-device-only")
        args.add("-o", bc_file)
        ctx.actions.run(
            executable = icx_tool,
            arguments = [args],
            outputs = [bc_file],
            inputs = depset([src], transitive = [common.headers, cc_toolchain.all_files]),
            env = env,
            mnemonic = "SyclCompileByteCode",
            progress_message = "Compiling %s" % src.path,
        )

        args = ctx.actions.args()
        # TODO: extract command line from a repo rule using a test.cpp?
        args.add_all([
            bc_file,
            "-spirv-max-version=1.4",
            "-spirv-debug-info-version=nonsemantic-shader-200",
            "-spirv-allow-unknown-intrinsics=llvm.genx.",
            "-spirv-ext=-all,+SPV_EXT_shader_atomic_float_add,+SPV_EXT_shader_atomic_float_min_max,+SPV_KHR_no_integer_wrap_decoration,+SPV_KHR_float_controls,+SPV_KHR_bit_instructions,+SPV_KHR_expect_assume,+SPV_KHR_linkonce_odr,+SPV_INTEL_subgroups,+SPV_INTEL_media_block_io,+SPV_INTEL_device_side_avc_motion_estimation,+SPV_INTEL_fpga_loop_controls,+SPV_INTEL_unstructured_loop_controls,+SPV_INTEL_fpga_reg,+SPV_INTEL_blocking_pipes,+SPV_INTEL_function_pointers,+SPV_INTEL_kernel_attributes,+SPV_INTEL_io_pipes,+SPV_INTEL_inline_assembly,+SPV_INTEL_arbitrary_precision_integers,+SPV_INTEL_float_controls2,+SPV_INTEL_vector_compute,+SPV_INTEL_fast_composite,+SPV_INTEL_arbitrary_precision_fixed_point,+SPV_INTEL_arbitrary_precision_floating_point,+SPV_INTEL_variable_length_array,+SPV_INTEL_fp_fast_math_mode,+SPV_INTEL_long_constant_composite,+SPV_INTEL_arithmetic_fence,+SPV_INTEL_global_variable_decorations,+SPV_INTEL_cache_controls,+SPV_INTEL_fpga_buffer_location,+SPV_INTEL_fpga_argument_interfaces,+SPV_INTEL_fpga_invocation_pipelining_attributes,+SPV_INTEL_fpga_latency_control,+SPV_KHR_shader_clock,+SPV_INTEL_bindless_images,+SPV_INTEL_task_sequence,+SPV_INTEL_optnone,+SPV_INTEL_bfloat16_conversion,+SPV_INTEL_joint_matrix,+SPV_INTEL_hw_thread_queries,+SPV_INTEL_memory_access_aliasing,+SPV_KHR_uniform_group_instructions,+SPV_INTEL_masked_gather_scatter,+SPV_INTEL_tensor_float32_conversion,+SPV_INTEL_optnone,+SPV_KHR_non_semantic_info,+SPV_KHR_cooperative_matrix,+SPV_EXT_shader_atomic_float16_add",
            "-o",
            spv_file,
        ])
        ctx.actions.run(
            executable = spv_tool,
            arguments = [args],
            outputs = [spv_file],
            inputs = depset([bc_file]),
            env = env,
            mnemonic = "SyclSPIRVCodegen",
            progress_message = "Generating SPIR-V for %s" % src.path,
        )
    return [
        DefaultInfo(files = depset(ret)),
        OutputGroupInfo(spv = ret),
    ]

spv_library = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "deps": attr.label_list(),
        "includes": attr.string_list(doc = "List of include dirs to be added to the compile line."),
        "copts": attr.string_list(doc = "Add these options to the CUDA device compilation command."),
        "defines": attr.string_list(doc = "List of defines to add to the compile line."),
    },
    fragments = ["cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    provides = [DefaultInfo, OutputGroupInfo],
)
