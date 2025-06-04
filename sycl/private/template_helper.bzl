"""
Copyright (c) 2025 Wenyi Tang
Author: Wenyi Tang
E-mail: wenyitang@outlook.com
"""

load("//sycl/private:gcc_helper.bzl", gcc_helper = "toolchain_helper")
load("//sycl/private:msvc_helper.bzl", msvc_helper = "toolchain_helper")
load("//sycl/private:os_helpers.bzl", "os_helper")

def _generate_build(repository_ctx, version, llvm_version):
    """Generate `@sycl//BUILD` or `@sycl_<component>//BUILD`

    Args:
        repository_ctx: repository_ctx
        version: substitution of %{version}
        llvm_version: substitution of %{llvm_version}
    """

    # stitch template fragment
    fragments = [
        Label("//sycl/private:templates/BUILD.sycl_shared"),
        Label("//sycl/private:templates/BUILD.sycl_headers"),
        Label("//sycl/private:templates/BUILD.sycl_build_setting"),
        Label("//sycl/private:templates/BUILD.icx"),
    ]

    template_content = []
    for frag in fragments:
        template_content.append("# Generated from fragment " + str(frag))
        template_content.append(repository_ctx.read(frag))

    template_content = "\n".join(template_content)

    template_path = repository_ctx.path("BUILD.tpl")
    repository_ctx.file(template_path, content = template_content, executable = False)

    substitutions = {
        "%{component_name}": "sycl",
        "%{version}": version,
        "%{llvm_version}": llvm_version,
    }
    repository_ctx.template("BUILD", template_path, substitutions = substitutions, executable = False)

def _generate_defs_bzl(repository_ctx, is_local_stk):
    tpl_label = Label("//sycl/private:templates/defs.bzl.tpl")
    substitutions = {
        "%{is_local_stk}": str(is_local_stk),
    }
    repository_ctx.template("defs.bzl", tpl_label, substitutions = substitutions, executable = False)

def _generate_toolchain_build(repository_ctx, sycl):
    paths = os_helper.resolve_labels(repository_ctx, [
        # required by msvc
        "//sycl/private:templates/BUILD.toolchain_icx_msvc",
        "//sycl/private:templates/windows_cc_toolchain_config.bzl",
        "@bazel_tools//tools/cpp:vc_installation_error.bat.tpl",
        "@bazel_tools//tools/cpp:clang_installation_error.bat.tpl",
        # required by unix
        "//sycl/private:templates/BUILD.toolchain_icx",
        "//sycl/private:templates/unix_cc_toolchain_config.bzl",
        "@bazel_tools//tools/cpp:generate_system_module_map.sh",
        "@bazel_tools//tools/cpp:armeabi_cc_toolchain_config.bzl",
        "@bazel_tools//tools/cpp:linux_cc_wrapper.sh.tpl",
        "@bazel_tools//tools/cpp:osx_cc_wrapper.sh.tpl",
    ])

    repo_name = repository_ctx.name.split("~")[-1]
    template_vars = dict({
        "%{platform_name}": repo_name,
    })
    if os_helper.is_windows(repository_ctx):
        msvc_vars_x64 = msvc_helper.get_msvc_vars(repository_ctx, paths, "x64")
        msvc_vars_x64["%{msvc_cl_path_x64}"] = sycl.icx
        msvc_vars_x64["%{msvc_link_path_x64}"] = sycl.icx
        msvc_vars_x64["%{llvm_spirv_path_x64}"] = sycl.llvm_spirv
        msvc_vars_x64["%{msvc_env_lib_x64}"] += ";".join([""] + sycl.lib_paths)
        msvc_vars_x64["%{msvc_env_include_x64}"] += ";".join([""] + sycl.include_paths)
        msvc_vars_x64["%{msvc_cxx_builtin_include_directories_x64}"] += ",\n        " + ",\n        ".join([
            "\"%s\"" % p
            for p in sycl.include_paths
        ])
        msvc_vars_x64["%{dbg_mode_debug_flag_x64}"] = "/debug:full"
        msvc_vars_x64["%{fastbuild_mode_debug_flag_x64}"] = "/debug:minimal"
        template_vars.update(msvc_vars_x64)

        repository_ctx.template(
            "toolchain/windows_cc_toolchain_config.bzl",
            paths["//sycl/private:templates/windows_cc_toolchain_config.bzl"],
            {},
        )
        repository_ctx.template(
            "toolchain/BUILD",
            paths["//sycl/private:templates/BUILD.toolchain_icx_msvc"],
            template_vars,
        )
    elif os_helper.is_linux(repository_ctx):
        template_vars["gcc"] = sycl.icx
        template_vars["llvm-cov"] = "{}/compiler/{}/bin/compiler/llvm-cov".format(sycl.path, sycl.version)
        template_vars["llvm-profdata"] = "{}/compiler/{}/bin/compiler/llvm-profdata".format(sycl.path, sycl.version)
        template_vars["llvm-spirv"] = sycl.llvm_spirv
        template_vars["ar"] = "{}/compiler/{}/bin/compiler/llvm-ar".format(sycl.path, sycl.version)
        template_vars["builtin_include_directories"] = sycl.include_paths
        gcc_helper.configure_unix_toolchain(repository_ctx, paths, "x86_64", template_vars)

template_helper = struct(
    generate_build = _generate_build,
    generate_defs_bzl = _generate_defs_bzl,
    generate_toolchain_build = _generate_toolchain_build,
)
