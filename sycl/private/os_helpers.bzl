load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_tools//tools/cpp:lib_cc_configure.bzl", "auto_configure_fail")

def if_linux(if_true, if_false = []):
    return select({
        "@platforms//os:linux": if_true,
        "//conditions:default": if_false,
    })

def if_windows(if_true, if_false = []):
    return select({
        "@platforms//os:windows": if_true,
        "//conditions:default": if_false,
    })

def cc_import_versioned_sos(name, shared_library):
    """Creates a cc_library that depends on all versioned .so files with the given prefix.

    If <shared_library> is path/to/foo.so, and it is a symlink to foo.so.<version>,
    this should be used instead of cc_import.
    The versioned files are typically needed at runtime, but not at build time.

    Args:
        name: Name of the cc_library.
        shared_library: Prefix of the versioned .so files.
    """

    # NOTE: only empty when the componnent is not installed on the system, say, cublas is not installed with apt-get
    so_paths = native.glob([shared_library + "*"], allow_empty = True)

    for p in so_paths:
        native.cc_import(
            name = paths.basename(p),
            shared_library = p,
            target_compatible_with = ["@platforms//os:linux"],
        )

    native.cc_library(
        name = name,
        deps = [":%s" % paths.basename(p) for p in so_paths],
    )

def _resolve_labels(repository_ctx, labels):
    """Resolves a collection of labels to their paths.

    Label resolution can cause the evaluation of Starlark functions to restart.
    For functions with side-effects (like the auto-configuration functions, which
    inspect the system and touch the file system), such restarts are costly.
    We cannot avoid the restarts, but we can minimize their penalty by resolving
    all labels upfront.

    Among other things, doing less work on restarts can cut analysis times by
    several seconds and may also prevent tickling kernel conditions that cause
    build failures.  See https://github.com/bazelbuild/bazel/issues/5196 for
    more details.

    Args:
      repository_ctx: The context with which to resolve the labels.
      labels: Labels to be resolved expressed as a list of strings.

    Returns:
      A dictionary with the labels as keys and their paths as values.
    """
    return dict([(label, repository_ctx.path(Label(label))) for label in labels])

def _is_windows(ctx):
    return ctx.os.name.lower().startswith("windows")

def _is_linux(ctx):
    return ctx.os.name.lower().startswith("linux")

def _lookup_env_var(env, name, default = None):
    """Lookup environment variable case-insensitive.

    If a matching (case-insensitive) entry is found in the env dict both
    the key and the value are returned. The returned key might differ from
    name in casing.

    If a matching key was found its value is returned otherwise
    the default is returned.

    Return a (key, value) tuple"""
    for key, value in env.items():
        if name.lower() == key.lower():
            return (key, value)
    return (name, default)

def _get_env_var(repository_ctx, name, default = None):
    """Returns a value from an environment variable."""
    return _lookup_env_var(repository_ctx.os.environ, name, default)[1]

def _get_path_env_var(repository_ctx, name):
    r"""Returns a path from an environment variable.

    Removes quotes, replaces '\' with '/', and strips trailing '\'s."""
    value = _get_env_var(repository_ctx, name)
    if value != None:
        if value[0] == "\"":
            if len(value) == 1 or value[-1] != "\"":
                auto_configure_fail("'%s' environment variable has no trailing quote" % name)
            value = value[1:-1]
        if "\\" in value:
            value = value.replace("\\", "/")
        if value[-1] == "/":
            value = value.rstrip("/")
    return value

os_helper = struct(
    resolve_labels = _resolve_labels,
    is_windows = _is_windows,
    is_linux = _is_linux,
    get_env_var = _get_env_var,
    get_path_env_var = _get_path_env_var,
)
