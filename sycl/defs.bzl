"""
Core rules for building SYCL projects.
"""

load("//sycl/private:defs.bzl", _requires_sycl = "requires_sycl")
load("//sycl/private:macros/icx_cc_binary.bzl", _icx_cc_binary = "icx_cc_binary")
load("//sycl/private:macros/icx_cc_library.bzl", _icx_cc_library = "icx_cc_library")
load("//sycl/private:macros/icx_cc_test.bzl", _icx_cc_test = "icx_cc_test")
load("//sycl/private:macros/sycl_binary.bzl", _sycl_binary = "sycl_binary")
load("//sycl/private:macros/sycl_library.bzl", _sycl_library = "sycl_library")
load("//sycl/private:macros/sycl_test.bzl", _sycl_test = "sycl_test")
load("//sycl/private:os_helpers.bzl", _if_linux = "if_linux", _if_windows = "if_windows")

# macros
icx_cc_binary = _icx_cc_binary
icx_cc_library = _icx_cc_library
icx_cc_test = _icx_cc_test
sycl_binary = _sycl_binary
sycl_library = _sycl_library
sycl_test = _sycl_test

if_linux = _if_linux
if_windows = _if_windows

requires_sycl = _requires_sycl
