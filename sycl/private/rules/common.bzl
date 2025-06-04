load("@bazel_skylib//lib:paths.bzl", "paths")

ALLOW_SYCL_HDRS = [
    ".cuh",
    ".h",
    ".hpp",
    ".hh",
    ".inl",
]

ALLOW_SYCL_SRCS = [
    ".cc",
    ".cpp",
    ".cu",
]

def _check_src_extension(file, allowed_src_files):
    for pattern in allowed_src_files:
        if file.basename.endswith(pattern):
            return True
    return False

def _resolve_workspace_root_includes(ctx):
    src_path = paths.normalize(ctx.label.workspace_root)
    bin_path = paths.normalize(paths.join(ctx.bin_dir.path, src_path))
    return src_path, bin_path

def _resolve_includes(ctx, path):
    if paths.is_absolute(path):
        fail("invalid absolute path", path)

    src_path = paths.normalize(paths.join(ctx.label.workspace_root, ctx.label.package, path))
    bin_path = paths.join(ctx.bin_dir.path, src_path)
    return src_path, bin_path

def create_common(ctx):
    """Helper to gather and process various information from `ctx` object to ease the parameter passing for internal macros.

    Args:
        ctx: The rule context.

    Returns:
        A struct containing various information such as includes, headers, defines, and transitive cc_info.
    """
    attr = ctx.attr

    all_cc_deps = [dep for dep in attr.deps if CcInfo in dep]
    merged_cc_info = cc_common.merge_cc_infos(cc_infos = [dep[CcInfo] for dep in all_cc_deps])

    # gather include info
    includes = merged_cc_info.compilation_context.includes.to_list()
    system_includes = []
    quote_includes = []
    quote_includes.extend(_resolve_workspace_root_includes(ctx))
    for inc in attr.includes:
        system_includes.extend(_resolve_includes(ctx, inc))
    system_includes.extend(merged_cc_info.compilation_context.system_includes.to_list())
    quote_includes.extend(merged_cc_info.compilation_context.quote_includes.to_list())

    # gather header info
    private_headers = []
    for fs in attr.srcs:
        hdr = [f for f in fs.files.to_list() if _check_src_extension(f, ALLOW_SYCL_HDRS)]
        private_headers.extend(hdr)
    headers = private_headers
    transitive_headers = [merged_cc_info.compilation_context.headers]

    # gather linker info
    transitive_linking_contexts = [merged_cc_info.linking_context]

    defines = merged_cc_info.compilation_context.defines

    return struct(
        includes = depset(includes) if includes else depset([]),
        quote_includes = depset(quote_includes) if quote_includes else depset([]),
        system_includes = depset(system_includes) if system_includes else depset([]),
        headers = depset(headers) if headers else depset([]),
        defines = depset(defines) if defines else depset([]),
        transitive_headers = transitive_headers,
        transitive_cc_info = merged_cc_info,
        transitive_linking_contexts = transitive_linking_contexts,
    )
