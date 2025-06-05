"""Generate `@sycl//`"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//sycl/private:os_helpers.bzl", "os_helper")
load("//sycl/private:template_helper.bzl", "template_helper")

def get_icx_version(repository_ctx, sycl_path):
    r"""Get icx version from oneAPI installation.

    Args:
        repository_ctx: The context with which to find paths.
        sycl_path: The path to the oneAPI SDK.

    Returns:
        str: icx version
    """
    bin_ext = ".exe" if os_helper.is_windows(repository_ctx) else ""
    oneapi_path = repository_ctx.path(sycl_path).get_child("compiler", "latest")
    icx_path = oneapi_path.get_child("bin/icx{}".format(bin_ext))
    cmd = [icx_path, "--version"]
    if os_helper.is_windows(repository_ctx):
        cmd.append("-nologo")
    ret = repository_ctx.execute(cmd)
    if ret.return_code != 0:
        fail("Failed to get icx version (%s): %s" % (ret.return_code, ret.stderr))
    full_version = ret.stdout.split("\n")[0].split(" ")[-1].strip("()")
    major_version, minor_version, _ = full_version.split(".", 2)
    return "{}.{}".format(major_version, minor_version)

def get_llvm_version(icx_version, sycl_path):
    r"""Get llvm version from oneAPI installation.

    Args:
        icx_version: The icx version.
        sycl_path: The path to the oneAPI SDK.

    Returns:
        str: llvm version
    """
    llvm_path = sycl_path.get_child("compiler", icx_version, "lib", "clang")
    for v in llvm_path.readdir():
        return v.basename
    return "llvm-unknown"

def find_oneapi_path(repository_ctx):
    r"""Find oneAPI installation on local machine.

    HINT:
        CMPLR_ROOT
        /opt/intel/oneapi/compiler/latest
        c:\Program Files (x86)\Intel\oneAPI\compiler\latest\

    Args:
        repository_ctx: _repository context object

    Returns:
        str: install root path of icpx
    """
    icpx_path = os_helper.get_path_env_var(repository_ctx, "CMPLR_ROOT")
    if icpx_path:
        return repository_ctx.path(icpx_path).dirname.dirname

    if os_helper.is_windows(repository_ctx):
        default_install_path = "C:/Program Files (x86)/Intel/oneAPI"
    else:
        default_install_path = "/opt/intel/oneapi"
    if repository_ctx.path(default_install_path).exists:
        return default_install_path

    return None

def _detect_local_sycl_toolkit(repository_ctx):
    sycl_path = repository_ctx.attr.toolkit_path
    if not sycl_path:
        sycl_path = find_oneapi_path(repository_ctx)
    if not sycl_path:
        icx_path = repository_ctx.which("icx")
        if icx_path:
            # ${CMPLR_ROOT}/bin/icx
            sycl_path = str(icx_path.dirname.dirname.dirname.dirname)
    if sycl_path != None and not repository_ctx.path(sycl_path).exists:
        sycl_path = None

    bin_ext = ".exe" if os_helper.is_windows(repository_ctx) else ""
    icx = "@rules_sycl//sycl/dummy:icx"
    ocloc = "@rules_sycl//sycl/dummy:ocloc"
    include_paths = [":empty"]
    lib_paths = [":empty"]
    icx_version = repository_ctx.attr.version
    if sycl_path != None:
        sycl_path = repository_ctx.path(sycl_path)
        if not icx_version:
            icx_version = get_icx_version(repository_ctx, sycl_path)
        llvm_version = get_llvm_version(icx_version, sycl_path)
        compiler_dir = sycl_path.get_child("compiler", icx_version)
        ocloc_dir = sycl_path.get_child("ocloc", icx_version)
        icx_path = compiler_dir.get_child("bin/icx{}".format(bin_ext))
        ocloc_path = ocloc_dir.get_child("bin/ocloc{}".format(bin_ext))
        if icx_path.exists:
            icx = str(icx_path)
        if ocloc_path.exists:
            ocloc = str(ocloc_path)
        include_paths = [
            compiler_dir.get_child("include"),
            compiler_dir.get_child("lib", "clang", llvm_version, "include"),
            compiler_dir.get_child("opt", "compiler", "include"),
        ]
        lib_paths = [compiler_dir.get_child("lib")]

    return struct(
        path = str(sycl_path),
        version = icx_version,
        llvm_version = get_llvm_version(icx_version, sycl_path),
        include_paths = [str(p) for p in include_paths],
        lib_paths = [str(p) for p in lib_paths],
        icx = icx,
        ocloc = ocloc,
    )

def detect_sycl_toolkit(repository_ctx):
    """Detect SYCL Toolkit.

    The path to SYCL Toolkit is determined as:
      - the value of `toolkit_path` passed to `sycl_toolkit` repo rule as an attribute
      - taken from `CMPLR_ROOT` environment variable or
      - determined through 'which icx' or
      - defaults to '/opt/intel/oneapi/compiler/latest' or
        'c:\\Program Files (x86)\\Intel\\oneAPI\\compiler\\latest'

    Args:
        repository_ctx: repository_ctx

    Returns:
        A struct contains the information of SYCL Toolkit.
    """
    return _detect_local_sycl_toolkit(repository_ctx)

def config_sycl_toolkit_and_icx(repository_ctx, sycl):
    """Generate `@sycl//BUILD` and `@sycl//defs.bzl` and `@sycl//toolchain/BUILD`

    Args:
        repository_ctx: repository_ctx
        sycl: The struct returned from detect_sycl_toolkit
    """

    # True: locally installed sycl toolkit (@sycl with full install of local CTK)
    # False: hermatic sycl toolkit (@sycl with alias of components)
    # None: sycl toolkit is not presented
    is_local_stk = None

    if is_local_stk == None and sycl.path != None:
        repository_ctx.symlink(sycl.path, "sycl")
        is_local_stk = True

    # Generate @sycl//BUILD
    template_helper.generate_build(repository_ctx, sycl.version, sycl.llvm_version)

    # Generate @sycl//defs.bzl
    template_helper.generate_defs_bzl(repository_ctx, is_local_stk == True)

    # Generate @sycl//toolchain/BUILD
    template_helper.generate_toolchain_build(repository_ctx, sycl)

def _sycl_toolkit_impl(repository_ctx):
    sycl = detect_sycl_toolkit(repository_ctx)
    config_sycl_toolkit_and_icx(repository_ctx, sycl)

sycl_toolkit = repository_rule(
    implementation = _sycl_toolkit_impl,
    attrs = {
        "toolkit_path": attr.string(doc = "Path to the oneAPI SDK, if empty the environment variable CMPLR_ROOT will be used to deduce this path."),
        "version": attr.string(doc = "sycl toolkit version. Required for deliverable toolkit only.", default = "latest"),
    },
    configure = True,
    local = True,
    environ = ["CMPLR_ROOT"],
)

def default_components_mapping(components):
    """Create a default components_mapping from list of component names.

    Args:
        components: list of string, a list of component names.
    """
    return {c: "@sycl_" + c for c in components}

def rules_sycl_dependencies():
    """Populate the dependencies for rules_sycl. This will setup other bazel rules as workspace dependencies"""
    maybe(
        name = "bazel_skylib",
        repo_rule = http_archive,
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
        ],
        sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
    )

    maybe(
        name = "platforms",
        repo_rule = http_archive,
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/1.0.0/platforms-1.0.0.tar.gz",
            "https://github.com/bazelbuild/platforms/releases/download/1.0.0/platforms-1.0.0.tar.gz",
        ],
        sha256 = "3384eb1c30762704fbe38e440204e114154086c8fc8a8c2e3e28441028c019a8",
    )

def rules_sycl_toolchains(
        name = "sycl",
        toolkit_path = None,
        version = "latest",
        register_toolchains = False):
    """Populate the @sycl repo.

    Args:
        name: must be "sycl".
        toolkit_path: Optionally specify the path to SYCL toolkit. If not specified, it will be detected automatically.
        version: str for sycl toolkit version. Required for deliverable toolkit only.
        register_toolchains: Register the toolchains if enabled.
    """

    if name != "sycl":
        fail("name must be 'sycl'")

    sycl_toolkit(
        name = name,
        toolkit_path = toolkit_path,
        version = version,
    )

    if register_toolchains:
        native.register_toolchains(
            "@{}//toolchain:icx-local-toolchain".format(name),
        )
