load("@rules_cuda//cuda/private:actions/compile.bzl", _compile = "compile")
load("@rules_cuda//cuda/private:actions/codegen.bzl", _device_codegen = "device_codegen")
load("@rules_cuda//cuda/private:cuda_helper.bzl", _cuda_helper = "cuda_helper")
load(
    "@rules_cuda//cuda/private:repositories.bzl",
    _config_clang = "config_clang",
    _config_cuda_toolkit_and_nvcc = "config_cuda_toolkit_and_nvcc",
    _detect_clang = "detect_clang",
    _detect_cuda_toolkit = "detect_cuda_toolkit",
)
load(
    "@rules_cuda//cuda/private:toolchain.bzl",
    _find_cuda_toolchain = "find_cuda_toolchain",
    _find_cuda_toolkit = "find_cuda_toolkit",
    _use_cuda_toolchain = "use_cuda_toolchain",
)
load("@rules_cuda//cuda/private:toolchain_config_lib.bzl", _config_helper = "config_helper")

# create a struct to group toolchain symbols semantically
toolchain = struct(
    use_cuda_toolchain = _use_cuda_toolchain,
    find_cuda_toolchain = _find_cuda_toolchain,
    find_cuda_toolkit = _find_cuda_toolkit,
)

cuda_helper = _cuda_helper
config_helper = _config_helper

# create a struct to group action symbols semantically
actions = struct(
    compile = _compile,
    device_codegen = _device_codegen,
)

# create a struct to group repositories symbols semantically
repositories = struct(
    config_clang = _config_clang,
    config_cuda_toolkit_and_nvcc = _config_cuda_toolkit_and_nvcc,
    detect_clang = _detect_clang,
    detect_cuda_toolkit = _detect_cuda_toolkit,
)
