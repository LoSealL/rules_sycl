"""Entry point for extensions used by bzlmod."""

load("//sycl/private:repositories.bzl", "sycl_toolkit")

sycl_toolkit_tag = tag_class(attrs = {
    "name": attr.string(mandatory = True, doc = "Name for the toolchain repository", default = "sycl"),
    "toolkit_path": attr.string(
        doc = "Path to the SYCL SDK, if empty the environment variable CMPLR_ROOT will be used to deduce this path.",
    ),
    "version": attr.string(doc = "sycl toolkit version. Required for deliverable toolkit only."),
})

def _find_modules(module_ctx):
    root = None
    our_module = None
    for mod in module_ctx.modules:
        if mod.is_root:
            root = mod
        if mod.name == "rules_sycl":
            our_module = mod
    if root == None:
        root = our_module
    if our_module == None:
        fail("Unable to find rules_sycl module")

    return root, our_module

def _module_tag_to_dict(t):
    return {attr: getattr(t, attr) for attr in dir(t)}

def _impl(module_ctx):
    # Toolchain configuration is only allowed in the root module, or in rules_sycl.
    root, rules_sycl = _find_modules(module_ctx)
    toolkits = None
    if root.tags.toolkit:
        toolkits = root.tags.toolkit
    else:
        toolkits = rules_sycl.tags.toolkit

    registrations = {}
    for toolkit in toolkits:
        if toolkit.name in registrations.keys():
            if toolkit.toolkit_path == registrations[toolkit.name].toolkit_path:
                # No problem to register a matching toolkit twice
                continue
            fail("Multiple conflicting toolkits declared for name {} ({} and {}".format(toolkit.name, toolkit.toolkit_path, registrations[toolkit.name].toolkit_path))
        else:
            registrations[toolkit.name] = toolkit
    for _, toolkit in registrations.items():
        sycl_toolkit(**_module_tag_to_dict(toolkit))

toolchain = module_extension(
    implementation = _impl,
    tag_classes = {
        "toolkit": sycl_toolkit_tag,
    },
)
