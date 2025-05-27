load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//sycl/private:providers.bzl", "SyclArchsInfo")

def _sycl_archs_flag_impl(ctx):
    specs_str = ctx.build_setting_value
    return SyclArchsInfo(arch_specs = specs_str)

sycl_archs_flag = rule(
    doc = """A build setting for specifying sycl archs to compile for.

To retain the flexibility of ICX, the [extended notation](https://docs.nvidia.com/sycl/sycl-compiler-driver-nvcc/index.html#extended-notation) is adopted.

When passing sycl_archs from commandline, its spec grammar is as follows:

    ARCH_SPECS   ::= ARCH_SPEC [ ';' ARCH_SPECS ]
    ARCH_SPEC    ::= [ VIRTUAL_ARCH ':' ] GPU_ARCHS
    GPU_ARCHS    ::= GPU_ARCH [ ',' GPU_ARCHS ]
    GPU_ARCH     ::= 'sm_' ARCH_NUMBER
                   | 'lto_' ARCH_NUMBER
                   | VIRTUAL_ARCH
    VIRTUAL_ARCH ::= 'compute_' ARCH_NUMBER
                   | 'lto_' ARCH_NUMBER
    ARCH_NUMBER  ::= (a string in predefined sycl_archs list)

E.g.:

- `compute_80:sm_80,sm_86`:
  Use `compute_80` PTX, generate cubin with `sm_80` and `sm_86`, no PTX embedded
- `compute_80:compute_80,sm_80,sm_86`:
  Use `compute_80` PTX, generate cubin with `sm_80` and `sm_86`, PTX embedded
- `compute_80:compute_80`:
  Embed `compute_80` PTX, fully relay on `ptxas`
- `sm_80,sm_86`:
  Same as `compute_80:sm_80,sm_86`, the arch with minimum integer value will be automatically populated.
- `sm_80;sm_86`:
  Two specs used.
- `compute_80`:
  Same as `compute_80:compute_80`

Best Practices:

- Library supports a full range of archs from xx to yy, you should embed the yy PTX
- Library supports a sparse range of archs from xx to yy, you should embed the xx PTX""",
    implementation = _sycl_archs_flag_impl,
    build_setting = config.string(flag = True),
    provides = [SyclArchsInfo],
)

def _repeatable_string_flag_impl(ctx):
    flags = ctx.build_setting_value
    if (flags == [""]):
        flags = []
    return BuildSettingInfo(value = flags)

repeatable_string_flag = rule(
    implementation = _repeatable_string_flag_impl,
    build_setting = config.string(flag = True, allow_multiple = True),
    provides = [BuildSettingInfo],
)
