"""
Copyright (c) 2025 Wenyi Tang
Author: Wenyi Tang
E-mail: wenyitang@outlook.com
"""

load(
    "@bazel_tools//tools/cpp:lib_cc_configure.bzl",
    "auto_configure_fail",
    "auto_configure_warning",
    "auto_configure_warning_maybe",
    "escape_string",
    "execute",
    "write_builtin_include_directory_paths",
)
load(
    "@bazel_tools//tools/cpp:windows_cc_configure.bzl",
    "find_llvm_path",
    "find_llvm_tool",
    "find_msvc_tool",
    "find_vc_path",
    "setup_vc_env_vars",
)
load("//sycl/private:os_helpers.bzl", "os_helper")

_targets_archs = {"x64": "amd64", "x86": "amd64_x86", "arm": "amd64_arm", "arm64": "amd64_arm64"}
_targets_lib_folder = {"x86": "", "arm": "arm", "arm64": "arm64"}

def _get_temp_env(repository_ctx):
    """Returns the value of TMP, or TEMP, or if both undefined then C:\\Windows."""
    tmp = os_helper.get_path_env_var(repository_ctx, "TMP")
    if not tmp:
        tmp = os_helper.get_path_env_var(repository_ctx, "TEMP")
    if not tmp:
        tmp = "C:\\Windows\\Temp"
        auto_configure_warning(
            "neither 'TMP' nor 'TEMP' environment variables are set, using '%s' as default" % tmp,
        )
    return tmp

def _is_vs_2017_or_2019(repository_ctx, vc_path):
    """Check if the installed VS version is Visual Studio 2017 or 2019."""

    # The layout of VC folder in VS 2017 and 2019 is different from that in VS 2015 and older versions.
    # In VS 2017 and 2019, it contains only three directories:
    # "Auxiliary", "Redist", "Tools"

    vc_2017_or_2019_contents = ["auxiliary", "redist", "tools"]
    vc_path_contents = [d.basename.lower() for d in repository_ctx.path(vc_path).readdir()]
    vc_path_contents = sorted(vc_path_contents)
    return vc_path_contents == vc_2017_or_2019_contents

def _find_vcvars_bat_script(repository_ctx, vc_path):
    """Find batch script to set up environment variables for VC. Doesn't %-escape the result."""
    if _is_vs_2017_or_2019(repository_ctx, vc_path):
        vcvars_script = vc_path + "\\Auxiliary\\Build\\VCVARSALL.BAT"
    else:
        vcvars_script = vc_path + "\\VCVARSALL.BAT"

    if not repository_ctx.path(vcvars_script).exists:
        return None

    return vcvars_script

def _get_vc_env_vars(repository_ctx, vc_path, msvc_vars_x64, target_arch):
    """Derive the environment variables set of a given target architecture from the environment variables of the x64 target.

       This is done to avoid running VCVARSALL.BAT script for every target architecture.

    Args:
        repository_ctx: the repository_ctx object
        vc_path: Visual C++ root directory
        msvc_vars_x64: values of MSVC toolchain including the environment variables for x64 target architecture
        target_arch: the target architecture to get its environment variables

    Returns:
        dictionary of envvars
    """
    env = {}
    if _is_vs_2017_or_2019(repository_ctx, vc_path):
        lib = msvc_vars_x64["%{msvc_env_lib_x64}"]
        full_version = _get_vc_full_version(repository_ctx, vc_path)
        tools_path = "%s\\Tools\\MSVC\\%s\\bin\\HostX64\\%s" % (vc_path, full_version, target_arch)

        # For native windows(10) on arm64 builds host toolchain runs in an emulated x86 environment
        if not repository_ctx.path(tools_path).exists:
            tools_path = "%s\\Tools\\MSVC\\%s\\bin\\HostX86\\%s" % (vc_path, full_version, target_arch)
    else:
        lib = msvc_vars_x64["%{msvc_env_lib_x64}"].replace("amd64", _targets_lib_folder[target_arch])
        tools_path = vc_path + "\\bin\\" + _targets_archs[target_arch]

    env["INCLUDE"] = msvc_vars_x64["%{msvc_env_include_x64}"]
    env["LIB"] = lib.replace("x64", target_arch)
    env["PATH"] = escape_string(tools_path.replace("\\", "\\\\")) + ";" + msvc_vars_x64["%{msvc_env_path_x64}"]
    return env

def _get_latest_subversion(repository_ctx, vc_path):
    """Get the latest subversion of a VS 2017/2019 installation.

    For VS 2017 & 2019, there could be multiple versions of VC build tools.
    The directories are like:
      <vc_path>\\Tools\\MSVC\\14.10.24930\\bin\\HostX64\\x64
      <vc_path>\\Tools\\MSVC\\14.16.27023\\bin\\HostX64\\x64
    This function should return 14.16.27023 in this case."""
    versions = [path.basename for path in repository_ctx.path(vc_path + "\\Tools\\MSVC").readdir()]
    if len(versions) < 1:
        auto_configure_warning_maybe(repository_ctx, "Cannot find any VC installation under BAZEL_VC(%s)" % vc_path)
        return None

    # Parse the version string into integers, then sort the integers to prevent textual sorting.
    version_list = []
    for version in versions:
        parts = [int(i) for i in version.split(".")]
        version_list.append((parts, version))

    version_list = sorted(version_list)
    latest_version = version_list[-1][1]

    auto_configure_warning_maybe(repository_ctx, "Found the following VC versions:\n%s\n\nChoosing the latest version = %s" % ("\n".join(versions), latest_version))
    return latest_version

def _get_vc_full_version(repository_ctx, vc_path):
    """Return the value of BAZEL_VC_FULL_VERSION if defined, otherwise the latest version."""
    version = os_helper.get_env_var(repository_ctx, "BAZEL_VC_FULL_VERSION")
    if version != None:
        return version
    return _get_latest_subversion(repository_ctx, vc_path)

def _find_msvc_tools(repository_ctx, vc_path, target_arch = "x64"):
    """Find the exact paths of the build tools in MSVC for the given target. Doesn't %-escape the result."""
    build_tools_paths = {}
    tools = _get_target_tools(target_arch)
    for tool_name in tools:
        build_tools_paths[tool_name] = find_msvc_tool(repository_ctx, vc_path, tools[tool_name], target_arch)
    return build_tools_paths

def _find_missing_vc_tools(repository_ctx, vc_path, target_arch = "x64"):
    """Check if any required tool for the given target architecture is missing under given VC path."""
    missing_tools = []
    if not _find_vcvars_bat_script(repository_ctx, vc_path):
        missing_tools.append("VCVARSALL.BAT")

    tools = _get_target_tools(target_arch)
    for tool_name in tools:
        if not find_msvc_tool(repository_ctx, vc_path, tools[tool_name], target_arch):
            missing_tools.append(tools[tool_name])
    return missing_tools

def _get_target_tools(target):
    """Return a list of required tools names and their filenames for a certain target."""
    tools = {
        "x64": {"CL": "cl.exe", "LINK": "link.exe", "LIB": "lib.exe", "ML": "ml64.exe"},
        "x86": {"CL": "cl.exe", "LINK": "link.exe", "LIB": "lib.exe", "ML": "ml.exe"},
        "arm": {"CL": "cl.exe", "LINK": "link.exe", "LIB": "lib.exe"},
        "arm64": {"CL": "cl.exe", "LINK": "link.exe", "LIB": "lib.exe"},
    }
    if tools.get(target) == None:
        auto_configure_fail("Target architecture %s is not recognized" % target)

    return tools.get(target)

def _is_support_debug_fastlink(repository_ctx, linker):
    """Run linker alone to see if it supports /DEBUG:FASTLINK."""
    if _use_clang_cl(repository_ctx):
        # LLVM's lld-link.exe doesn't support /DEBUG:FASTLINK.
        return False
    result = execute(repository_ctx, [linker], expect_failure = True)
    return result.find("/DEBUG[:{FASTLINK|FULL|NONE}]") != -1

def _is_support_parse_showincludes(repository_ctx, cl, env):
    repository_ctx.file(
        "main.cpp",
        "#include \"bazel_showincludes.h\"\nint main(){}\n",
    )
    repository_ctx.file(
        "bazel_showincludes.h",
        "\n",
    )
    result = execute(
        repository_ctx,
        [cl, "/nologo", "/showIncludes", "/c", "main.cpp", "/out", "main.exe", "/Fo", "main.obj"],
        # Attempt to force English language. This may fail if the language pack isn't installed.
        environment = env | {"VSLANG": "1033"},
    )
    for file in ["main.cpp", "bazel_showincludes.h", "main.exe", "main.obj"]:
        execute(repository_ctx, ["cmd", "/C", "del", file], expect_empty_output = True)
    return any([
        line.startswith("Note: including file:") and line.endswith("bazel_showincludes.h")
        for line in result.split("\n")
    ])

def _use_clang_cl(repository_ctx):
    """Returns True if USE_CLANG_CL is set to 1."""
    return os_helper.get_env_var(repository_ctx, "USE_CLANG_CL", default = "0") == "1"

def _find_missing_llvm_tools(repository_ctx, llvm_path):
    """Check if any required tool is missing under given LLVM path."""
    missing_tools = []
    for tool in ["clang-cl.exe", "lld-link.exe", "llvm-lib.exe"]:
        if not find_llvm_tool(repository_ctx, llvm_path, tool):
            missing_tools.append(tool)

    return missing_tools

def _get_clang_version(repository_ctx, clang_cl):
    result = repository_ctx.execute([clang_cl, "-v"])
    first_line = result.stderr.strip().splitlines()[0].strip()

    # The first line of stderr should look like "[vendor ]clang version X.X.X"
    if result.return_code != 0 or first_line.find("clang version ") == -1:
        auto_configure_fail("Failed to get clang version by running \"%s -v\"" % clang_cl)
    return first_line.split(" ")[-1]

def _get_clang_dir(repository_ctx, llvm_path, clang_version):
    """Get the clang installation directory."""

    # The clang_version string format is "X.X.X"
    clang_dir = llvm_path + "\\lib\\clang\\" + clang_version
    if repository_ctx.path(clang_dir).exists:
        return clang_dir

    # Clang 16 changed the install path to use just the major number.
    clang_major_version = clang_version.split(".")[0]
    return llvm_path + "\\lib\\clang\\" + clang_major_version

def _get_msvc_vars(repository_ctx, paths, target_arch = "x64", msvc_vars_x64 = None):
    """Get the variables we need to populate the MSVC toolchains."""
    msvc_vars = dict()
    vc_path = find_vc_path(repository_ctx)
    missing_tools = None

    if not vc_path:
        repository_ctx.template(
            "vc_installation_error_" + target_arch + ".bat",
            paths["@bazel_tools//tools/cpp:vc_installation_error.bat.tpl"],
            {"%{vc_error_message}": ""},
        )
    else:
        missing_tools = _find_missing_vc_tools(repository_ctx, vc_path, target_arch)
        if missing_tools:
            message = "\r\n".join([
                "echo. 1>&2",
                "echo Visual C++ build tools seems to be installed at %s 1>&2" % vc_path,
                "echo But Bazel can't find the following tools: 1>&2",
                "echo     %s 1>&2" % ", ".join(missing_tools),
                "echo for %s target architecture 1>&2" % target_arch,
                "echo. 1>&2",
            ])
            repository_ctx.template(
                "vc_installation_error_" + target_arch + ".bat",
                paths["@bazel_tools//tools/cpp:vc_installation_error.bat.tpl"],
                {"%{vc_error_message}": message},
            )

    if not vc_path or missing_tools:
        write_builtin_include_directory_paths(repository_ctx, "msvc", [], file_suffix = "_msvc")
        msvc_vars = {
            "%{msvc_env_tmp_" + target_arch + "}": "msvc_not_found",
            "%{msvc_env_include_" + target_arch + "}": "msvc_not_found",
            "%{msvc_cxx_builtin_include_directories_" + target_arch + "}": "",
            "%{msvc_env_path_" + target_arch + "}": "msvc_not_found",
            "%{msvc_env_lib_" + target_arch + "}": "msvc_not_found",
            "%{msvc_cl_path_" + target_arch + "}": "vc_installation_error_" + target_arch + ".bat",
            "%{msvc_ml_path_" + target_arch + "}": "vc_installation_error_" + target_arch + ".bat",
            "%{msvc_link_path_" + target_arch + "}": "vc_installation_error_" + target_arch + ".bat",
            "%{msvc_lib_path_" + target_arch + "}": "vc_installation_error_" + target_arch + ".bat",
            "%{dbg_mode_debug_flag_" + target_arch + "}": "/DEBUG",
            "%{fastbuild_mode_debug_flag_" + target_arch + "}": "/DEBUG",
            "%{msvc_parse_showincludes_" + target_arch + "}": repr(False),
        }
        return msvc_vars

    if msvc_vars_x64:
        env = _get_vc_env_vars(repository_ctx, vc_path, msvc_vars_x64, target_arch)
    else:
        env = setup_vc_env_vars(repository_ctx, vc_path)
    escaped_tmp_dir = escape_string(_get_temp_env(repository_ctx).replace("\\", "\\\\"))
    escaped_include_paths = escape_string(env["INCLUDE"])

    build_tools = {}
    llvm_path = ""
    if _use_clang_cl(repository_ctx):
        llvm_path = find_llvm_path(repository_ctx)
        if not llvm_path:
            auto_configure_fail("\nUSE_CLANG_CL is set to 1, but Bazel cannot find Clang installation on your system.\n" +
                                "Please install Clang via http://releases.llvm.org/download.html\n")

        build_tools["CL"] = find_llvm_tool(repository_ctx, llvm_path, "clang-cl.exe")
        build_tools["ML"] = find_msvc_tool(repository_ctx, vc_path, "ml64.exe", "x64")
        build_tools["LINK"] = find_llvm_tool(repository_ctx, llvm_path, "lld-link.exe")
        if not build_tools["LINK"]:
            build_tools["LINK"] = find_msvc_tool(repository_ctx, vc_path, "link.exe", "x64")
        build_tools["LIB"] = find_llvm_tool(repository_ctx, llvm_path, "llvm-lib.exe")
        if not build_tools["LIB"]:
            build_tools["LIB"] = find_msvc_tool(repository_ctx, vc_path, "lib.exe", "x64")
    else:
        build_tools = _find_msvc_tools(repository_ctx, vc_path, target_arch)

    escaped_cxx_include_directories = []
    for path in escaped_include_paths.split(";"):
        if path:
            escaped_cxx_include_directories.append("\"%s\"" % path)
    if llvm_path:
        clang_version = _get_clang_version(repository_ctx, build_tools["CL"])
        clang_dir = _get_clang_dir(repository_ctx, llvm_path, clang_version)
        clang_include_path = (clang_dir + "\\include").replace("\\", "\\\\")
        escaped_cxx_include_directories.append("\"%s\"" % clang_include_path)
        clang_lib_path = (clang_dir + "\\lib\\windows").replace("\\", "\\\\")
        env["LIB"] = escape_string(env["LIB"]) + ";" + clang_lib_path

    support_debug_fastlink = _is_support_debug_fastlink(repository_ctx, build_tools["LINK"])
    write_builtin_include_directory_paths(repository_ctx, "msvc", escaped_cxx_include_directories, file_suffix = "_msvc")

    support_parse_showincludes = _is_support_parse_showincludes(repository_ctx, build_tools["CL"], env)
    if not support_parse_showincludes:
        auto_configure_warning("""
Header pruning has been disabled since Bazel failed to recognize the output of /showIncludes.
This can result in unnecessary recompilation.
Fix this by installing the English language pack for the Visual Studio installation at {} and run 'bazel sync --configure'.""".format(vc_path))

    msvc_vars = {
        "%{msvc_env_tmp_" + target_arch + "}": escaped_tmp_dir,
        "%{msvc_env_include_" + target_arch + "}": escaped_include_paths,
        "%{msvc_cxx_builtin_include_directories_" + target_arch + "}": "        " + ",\n        ".join(escaped_cxx_include_directories),
        "%{msvc_env_path_" + target_arch + "}": escape_string(env["PATH"]),
        "%{msvc_env_lib_" + target_arch + "}": escape_string(env["LIB"]),
        "%{msvc_cl_path_" + target_arch + "}": build_tools["CL"],
        "%{msvc_ml_path_" + target_arch + "}": build_tools.get("ML", "msvc_arm_toolchain_does_not_support_ml"),
        "%{msvc_link_path_" + target_arch + "}": build_tools["LINK"],
        "%{msvc_lib_path_" + target_arch + "}": build_tools["LIB"],
        "%{msvc_parse_showincludes_" + target_arch + "}": repr(support_parse_showincludes),
        "%{dbg_mode_debug_flag_" + target_arch + "}": "/DEBUG:FULL" if support_debug_fastlink else "/DEBUG",
        "%{fastbuild_mode_debug_flag_" + target_arch + "}": "/DEBUG:FASTLINK" if support_debug_fastlink else "/DEBUG",
    }
    return msvc_vars

def _get_clang_cl_vars(repository_ctx, paths, msvc_vars, target_arch):
    """Get the variables we need to populate the clang-cl toolchains."""
    llvm_path = find_llvm_path(repository_ctx)
    error_script = None
    if msvc_vars["%{msvc_cl_path_" + target_arch + "}"] == "vc_installation_error_{}.bat".format(target_arch):
        error_script = "vc_installation_error_{}.bat".format(target_arch)
    elif not llvm_path:
        repository_ctx.template(
            "clang_installation_error.bat",
            paths["@bazel_tools//tools/cpp:clang_installation_error.bat.tpl"],
            {"%{clang_error_message}": ""},
        )
        error_script = "clang_installation_error.bat"
    else:
        missing_tools = _find_missing_llvm_tools(repository_ctx, llvm_path)
        if missing_tools:
            message = "\r\n".join([
                "echo. 1>&2",
                "echo LLVM/Clang seems to be installed at %s 1>&2" % llvm_path,
                "echo But Bazel can't find the following tools: 1>&2",
                "echo     %s 1>&2" % ", ".join(missing_tools),
                "echo. 1>&2",
            ])
            repository_ctx.template(
                "clang_installation_error.bat",
                paths["@bazel_tools//tools/cpp:clang_installation_error.bat.tpl"],
                {"%{clang_error_message}": message},
            )
            error_script = "clang_installation_error.bat"

    if error_script:
        write_builtin_include_directory_paths(repository_ctx, "clang-cl", [], file_suffix = "_clangcl")
        clang_cl_vars = {
            "%{clang_cl_env_tmp_" + target_arch + "}": "clang_cl_not_found",
            "%{clang_cl_env_path_" + target_arch + "}": "clang_cl_not_found",
            "%{clang_cl_env_include_" + target_arch + "}": "clang_cl_not_found",
            "%{clang_cl_env_lib_" + target_arch + "}": "clang_cl_not_found",
            "%{clang_cl_cl_path_" + target_arch + "}": error_script,
            "%{clang_cl_link_path_" + target_arch + "}": error_script,
            "%{clang_cl_lib_path_" + target_arch + "}": error_script,
            "%{clang_cl_ml_path_" + target_arch + "}": error_script,
            "%{clang_cl_dbg_mode_debug_flag_" + target_arch + "}": "/DEBUG",
            "%{clang_cl_fastbuild_mode_debug_flag_" + target_arch + "}": "/DEBUG",
            "%{clang_cl_cxx_builtin_include_directories_" + target_arch + "}": "",
            "%{clang_cl_parse_showincludes_" + target_arch + "}": repr(False),
        }
        return clang_cl_vars

    clang_cl_path = find_llvm_tool(repository_ctx, llvm_path, "clang-cl.exe")
    lld_link_path = find_llvm_tool(repository_ctx, llvm_path, "lld-link.exe")
    llvm_lib_path = find_llvm_tool(repository_ctx, llvm_path, "llvm-lib.exe")

    clang_version = _get_clang_version(repository_ctx, clang_cl_path)
    clang_dir = _get_clang_dir(repository_ctx, llvm_path, clang_version)
    clang_include_path = (clang_dir + "\\include").replace("\\", "\\\\")
    clang_lib_path = (clang_dir + "\\lib\\windows").replace("\\", "\\\\")

    clang_cl_include_directories = msvc_vars["%{msvc_cxx_builtin_include_directories_" + target_arch + "}"] + (",\n        \"%s\"" % clang_include_path)
    write_builtin_include_directory_paths(repository_ctx, "clang-cl", [clang_cl_include_directories], file_suffix = "_clangcl")
    clang_cl_vars = {
        "%{clang_cl_env_tmp_" + target_arch + "}": msvc_vars["%{msvc_env_tmp_" + target_arch + "}"],
        "%{clang_cl_env_path_" + target_arch + "}": msvc_vars["%{msvc_env_path_" + target_arch + "}"],
        "%{clang_cl_env_include_" + target_arch + "}": msvc_vars["%{msvc_env_include_" + target_arch + "}"] + ";" + clang_include_path,
        "%{clang_cl_env_lib_" + target_arch + "}": msvc_vars["%{msvc_env_lib_" + target_arch + "}"] + ";" + clang_lib_path,
        "%{clang_cl_cxx_builtin_include_directories_" + target_arch + "}": clang_cl_include_directories,
        "%{clang_cl_cl_path_" + target_arch + "}": clang_cl_path,
        "%{clang_cl_link_path_" + target_arch + "}": lld_link_path,
        "%{clang_cl_lib_path_" + target_arch + "}": llvm_lib_path,
        "%{clang_cl_ml_path_" + target_arch + "}": clang_cl_path,
        # LLVM's lld-link.exe doesn't support /DEBUG:FASTLINK.
        "%{clang_cl_dbg_mode_debug_flag_" + target_arch + "}": "/DEBUG",
        "%{clang_cl_fastbuild_mode_debug_flag_" + target_arch + "}": "/DEBUG",
        # clang-cl always emits the English language version of the /showIncludes prefix.
        "%{clang_cl_parse_showincludes_" + target_arch + "}": repr(True),
    }
    return clang_cl_vars

toolchain_helper = struct(
    get_msvc_vars = _get_msvc_vars,
    get_clang_cl_vars = _get_clang_cl_vars,
)
