""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", CC_ACTION_NAMES = "ACTION_NAMES")
load("//sycl/private:action_names.bzl", "ACTION_NAMES")
load("//sycl/private:actions/compile.bzl", "compile")
load("//sycl/private:sycl_helper.bzl", "sycl_helper")
load("//sycl/private:toolchain.bzl", "find_sycl_toolkit")

def device_codegen(
        ctx,
        sycl_toolchain,
        cc_toolchain,
        objects,
        common,
        pic = False,
        rdc = False,
        dlto = False):
    """Perform device link, return a dlink-ed object file.

    Notes:
        Compilation is carried out during device linking, which involves the embeeding of the fatbin into the resulting object `File`.

    Args:
        ctx: A [context object](https://bazel.build/rules/lib/ctx).
        sycl_toolchain: A `platform_common.ToolchainInfo` of a sycl toolchain, Can be obtained with `find_sycl_toolchain(ctx)`.
        cc_toolchain: A `CcToolchainInfo`. Can be obtained with `find_cpp_toolchain(ctx)`.
        objects: A `depset` of `File`s to be device linked.
        common: A sycl common object. Can be obtained with `sycl_helper.create_common(ctx)`
        pic: Whether the `objects` are compiled for position independent code.
        rdc: Whether the `objects` are device linked for relocatable device code.
        dlto: Whether the device link time optimization is enabled.

    Returns:
        An deviced linked object `File`.
    """
    sycl_feature_config = sycl_helper.configure_features(ctx, sycl_toolchain, requested_features = [ACTION_NAMES.device_codegen])
    if sycl_helper.is_enabled(sycl_feature_config, "supports_compiler_device_codegen"):
        return _compiler_device_codegen(ctx, sycl_toolchain, cc_toolchain, sycl_feature_config, objects, common, pic = pic, rdc = rdc, dlto = dlto)
    elif sycl_helper.is_enabled(sycl_feature_config, "supports_wrapper_device_codegen"):
        return _wrapper_device_codegen(ctx, sycl_toolchain, cc_toolchain, objects, common, pic = pic, rdc = rdc, dlto = dlto)
    else:
        fail("toolchain must be configured to enable feature supports_compiler_device_codegen or supports_wrapper_device_codegen.")

def _compiler_device_codegen(
        ctx,
        sycl_toolchain,
        cc_toolchain,
        sycl_feature_config,
        objects,
        common,
        pic = False,
        rdc = False,
        dlto = False):
    """perform compiler supported native device link, return a dlink-ed object file"""
    if not rdc:
        fail("device link is only meaningful on building relocatable device code")

    actions = ctx.actions
    cc_feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    host_compiler = cc_common.get_tool_for_action(feature_configuration = cc_feature_configuration, action_name = CC_ACTION_NAMES.cpp_compile)
    sycl_compiler = sycl_toolchain.compiler_executable

    artifact_category_name = sycl_helper.get_artifact_category_from_action(ACTION_NAMES.device_codegen, pic, rdc)
    basename = ctx.attr.name + "_dlink"
    filename = sycl_helper.get_artifact_name(sycl_toolchain, artifact_category_name, basename)

    obj_file = actions.declare_file("_objs/{}/{}".format(ctx.attr.name, filename))

    var = sycl_helper.create_device_codegen_variables(
        sycl_toolchain,
        sycl_feature_config,
        common.sycl_archs_info,
        common.sysroot,
        output_file = obj_file.path,
        host_compiler = host_compiler,
        host_compile_flags = common.host_compile_flags,
        user_link_flags = common.link_flags,
        use_pic = pic,
    )
    cmd = sycl_helper.get_command_line(sycl_feature_config, ACTION_NAMES.device_codegen, var)
    env = sycl_helper.get_environment_variables(sycl_feature_config, ACTION_NAMES.device_codegen, var)
    args = actions.args()
    args.add_all(cmd)
    args.add_all(objects)

    actions.run(
        executable = sycl_compiler,
        arguments = [args],
        outputs = [obj_file],
        inputs = depset(transitive = [objects, cc_toolchain.all_files, sycl_toolchain.all_files]),
        env = env,
        mnemonic = "SyclDeviceLink",
        progress_message = "Device linking %{output}",
    )
    return obj_file

def _wrapper_device_codegen(
        ctx,
        sycl_toolchain,
        cc_toolchain,
        objects,
        common,
        pic = False,
        rdc = False,
        dlto = False):
    """perform bazel macro supported device link, return a dlink-ed object file"""
    if not rdc:
        fail("device link is only meaningful on building relocatable device code")

    sycl_toolkit = find_sycl_toolkit(ctx)

    actions = ctx.actions
    pic_suffix = "_pic" if pic else ""

    # Device-link to cubins for each gpu architecture. The stage1 compiled PTX is embedded in the object files.
    # We don't need to do any thing about it, presumably.
    register_h = None
    cubins = []
    images = []
    obj_args = actions.args()
    obj_args.add_all(objects)
    if len(common.sycl_archs_info.arch_specs) == 0:
        fail('sycl toolchain "' + sycl_toolchain.name + '" is configured to enable feature supports_wrapper_device_codegen,' +
             " at least one sycl arch must be specified.")
    for arch_spec in common.sycl_archs_info.arch_specs:
        for stage2_arch in arch_spec.stage2_archs:
            if stage2_arch.gpu:
                arch = "sm_" + stage2_arch.arch
            elif stage2_arch.lto:
                arch = "lto_" + stage2_arch.arch
            else:
                # PTX is JIT-linked at runtime
                continue

            register_h = ctx.actions.declare_file("_dlink{suffix}/{0}/{0}_register_{1}.h".format(ctx.attr.name, arch, suffix = pic_suffix))
            cubin = ctx.actions.declare_file("_dlink{suffix}/{0}/{0}_{1}.cubin".format(ctx.attr.name, arch, suffix = pic_suffix))
            ctx.actions.run(
                outputs = [register_h, cubin],
                inputs = objects,
                executable = sycl_toolkit.nvlink,
                arguments = [
                    "--arch=" + arch,
                    "--register-link-binaries=" + register_h.path,
                    "--output-file=" + cubin.path,
                    obj_args,
                ],
                mnemonic = "nvlink",
            )
            cubins.append(cubin)
            images.append("--image=profile={},file={}".format(arch, cubin.path))

    # Generate fatbin header from all cubins.
    fatbin = ctx.actions.declare_file("_dlink{suffix}/{0}/{0}.fatbin".format(ctx.attr.name, suffix = pic_suffix))
    fatbin_h = ctx.actions.declare_file("_dlink{suffix}/{0}/{0}_fatbin.h".format(ctx.attr.name, suffix = pic_suffix))

    arguments = [
        "-64",
        "--cmdline=--compile-only",
        "--link",
        "--compress-all",
        "--create=" + fatbin.path,
        "--embedded-fatbin=" + fatbin_h.path,
    ]
    bin2c = sycl_toolkit.bin2c
    if (sycl_toolkit.version_major, sycl_toolkit.version_minor) <= (10, 1):
        arguments.append("--bin2c-path=%s" % bin2c.dirname)
    ctx.actions.run(
        outputs = [fatbin, fatbin_h],
        inputs = cubins,
        executable = sycl_toolkit.fatbinary,
        arguments = arguments + images,
        tools = [bin2c],
        mnemonic = "fatbinary",
    )

    # Generate the source file #including the headers generated above.
    fatbin_c = ctx.actions.declare_file("_dlink{suffix}/{0}/{0}.cu".format(ctx.attr.name, suffix = pic_suffix))
    ctx.actions.expand_template(
        output = fatbin_c,
        template = sycl_toolkit.link_stub,
        substitutions = {
            "REGISTERLINKBINARYFILE": '"{}"'.format(register_h.short_path),
            "FATBINFILE": '"{}"'.format(fatbin_h.short_path),
        },
    )

    # cc_common.compile will cause file conflict for pic and non-pic objects,
    # and it accepts only one set of src files. But pic fatbin_c and non-pic
    # fatbin_c have different compilation trajectories. This makes me feel bad.
    # Just avoid cc_common.compile at all.
    compile_common = sycl_helper.create_common_info(
        # this is useless
        sycl_archs_info = common.sycl_archs_info,
        headers = [fatbin_h, register_h],
        defines = [
            # Silence warning about including internal header.
            "__SYCL_INCLUDE_COMPILER_INTERNAL_HEADERS__",
            # Macros that need to be defined starting with SYCL 10.
            "__NV_EXTRA_INITIALIZATION=",
            "__NV_EXTRA_FINALIZATION=",
        ],
        includes = common.includes,
        system_includes = common.system_includes,
        quote_includes = common.quote_includes,
        # suppress sycl mode as c++ mode
        compile_flags = ["-x", "c++"],
        host_compile_flags = common.host_compile_flags,
    )
    ret = compile(ctx, sycl_toolchain, cc_toolchain, srcs = [fatbin_c], common = compile_common, pic = pic, rdc = rdc, _prefix = "_objs/_dlink")
    return ret[0]
