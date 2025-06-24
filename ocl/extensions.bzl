load(":repositories.bzl", "rules_ocl_dependencies")

def load_ocl_dependencies(ctx):
    rules_ocl_dependencies()

opencl_extension = module_extension(
    implementation = load_ocl_dependencies,
)
