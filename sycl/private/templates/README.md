## Template files

- `BUILD.icx`: For `sycl` repo (toolkit + toolchain) and `sycl_runtime`
- `BUILD.sycl_headers`: For `sycl_headers` headers
- `BUILD.sycl_build_setting`: For `sycl` repo (toolkit + toolchain) build_setting
- `BUILD.toolchain_icx`: For oneAPI ICPX compilation toolchain.
- `BUILD.toolchain_icx_msvc`: For oneAPI ICPX compilation with (MSVC as host compiler) toolchain.

## Repository organization

We organize the generated repo as follows

```
<repo_root>              # bazel unconditionally creates a directory for us
├── sycl/                # sycl for local toolkit, component name otherwise
│   ├── %{version}/      # all toolchain libs and binaries under the specific version
│   ├── compiler/%{version}/bin/
│   ├── compiler/%{version}/include/
│   ├── compiler/%{version}/lib/
├── defs.bzl             # generated
├── BUILD                # generated with template_helper
└── WORKSPACE            # generated
```
