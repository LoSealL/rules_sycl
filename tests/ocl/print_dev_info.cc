/****************************************
 * Copyright (c) 2025 Wenyi Tang
 * Author: Wenyi Tang
 * E-mail: wenyitang@outlook.com
 * Description: Print OpenCL device information
 ****************************************/
#define CL_HPP_ENABLE_EXCEPTIONS
#include <CL/opencl.hpp>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

// 打印设备信息的函数
void printDeviceInfo(const cl::Device &device) {
  try {
    // 基本信息
    std::cout << "Device Name: " << device.getInfo<CL_DEVICE_NAME>()
              << std::endl;
    std::cout << "Device Vendor: " << device.getInfo<CL_DEVICE_VENDOR>()
              << std::endl;
    std::cout << "Device Version: " << device.getInfo<CL_DEVICE_VERSION>()
              << std::endl;
    std::cout << "OpenCL C Version: "
              << device.getInfo<CL_DEVICE_OPENCL_C_VERSION>() << std::endl;

    // 类型信息
    cl_device_type deviceType = device.getInfo<CL_DEVICE_TYPE>();
    std::cout << "Device Type: ";
    if (deviceType & CL_DEVICE_TYPE_CPU)
      std::cout << "CPU ";
    if (deviceType & CL_DEVICE_TYPE_GPU)
      std::cout << "GPU ";
    if (deviceType & CL_DEVICE_TYPE_ACCELERATOR)
      std::cout << "ACCELERATOR ";
    if (deviceType & CL_DEVICE_TYPE_DEFAULT)
      std::cout << "DEFAULT ";
    std::cout << std::endl;

    // 硬件信息
    std::cout << "Max Compute Units: "
              << device.getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>() << std::endl;
    std::cout << "Max Work Item Dimensions: "
              << device.getInfo<CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS>()
              << std::endl;

    // 获取最大工作组大小
    std::vector<size_t> maxWorkItemSizes =
        device.getInfo<CL_DEVICE_MAX_WORK_ITEM_SIZES>();
    std::cout << "Max Work Item Sizes: ";
    for (size_t i = 0; i < maxWorkItemSizes.size(); i++) {
      std::cout << maxWorkItemSizes[i];
      if (i < maxWorkItemSizes.size() - 1)
        std::cout << " x ";
    }
    std::cout << std::endl;

    std::cout << "Max Work Group Size: "
              << device.getInfo<CL_DEVICE_MAX_WORK_GROUP_SIZE>() << std::endl;

    // 内存信息
    std::cout << "Global Memory Size: "
              << (device.getInfo<CL_DEVICE_GLOBAL_MEM_SIZE>() / (1024 * 1024))
              << " MB" << std::endl;
    std::cout << "Local Memory Size: "
              << (device.getInfo<CL_DEVICE_LOCAL_MEM_SIZE>() / 1024) << " KB"
              << std::endl;
    std::cout << "Max Memory Allocation Size: "
              << (device.getInfo<CL_DEVICE_MAX_MEM_ALLOC_SIZE>() /
                  (1024 * 1024))
              << " MB" << std::endl;

    // 扩展信息
    std::cout << "Device Extensions: " << device.getInfo<CL_DEVICE_EXTENSIONS>()
              << std::endl;

    std::cout << std::string(60, '-') << std::endl;
  } catch (const cl::Error &e) {
    std::cerr << "OpenCL Error: " << e.what() << " (" << e.err() << ")"
              << std::endl;
  }
}

int main() {
  try {
    // 获取所有平台
    std::vector<cl::Platform> platforms;
    cl::Platform::get(&platforms);

    if (platforms.empty()) {
      std::cerr << "No OpenCL platforms found!" << std::endl;
      return 1;
    }

    std::cout << "Found " << platforms.size() << " OpenCL platform(s)"
              << std::endl;
    std::cout << std::string(60, '-') << std::endl;

    // 遍历每个平台
    for (size_t i = 0; i < platforms.size(); i++) {
      std::cout << "Platform " << (i + 1) << ":" << std::endl;
      std::cout << "  Name: " << platforms[i].getInfo<CL_PLATFORM_NAME>()
                << std::endl;
      std::cout << "  Vendor: " << platforms[i].getInfo<CL_PLATFORM_VENDOR>()
                << std::endl;
      std::cout << "  Version: " << platforms[i].getInfo<CL_PLATFORM_VERSION>()
                << std::endl;
      std::cout << "  Profile: " << platforms[i].getInfo<CL_PLATFORM_PROFILE>()
                << std::endl;

      // 获取该平台上的所有设备
      std::vector<cl::Device> devices;
      platforms[i].getDevices(CL_DEVICE_TYPE_ALL, &devices);

      if (devices.empty()) {
        std::cout << "  No devices found on this platform!" << std::endl;
      } else {
        std::cout << "  Found " << devices.size() << " device(s)" << std::endl;
        std::cout << std::string(60, '-') << std::endl;

        // 打印每个设备的信息
        for (size_t j = 0; j < devices.size(); j++) {
          std::cout << "Device " << (j + 1) << " on Platform " << (i + 1) << ":"
                    << std::endl;
          printDeviceInfo(devices[j]);
        }
      }

      std::cout << std::string(60, '-') << std::endl;
    }

  } catch (const cl::Error &e) {
    std::cerr << "OpenCL Error: " << e.what() << " (" << e.err() << ")"
              << std::endl;
    return 1;
  }

  return 0;
}
