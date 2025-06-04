/****************************************
 * Copyright (c) 2025 Wenyi Tang
 * Author: Wenyi Tang
 * E-mail: wenyitang@outlook.com
 * Description:
 ****************************************/
#include <sycl/sycl.hpp>
#include <vector>

void vadd(sycl::queue &q, void *dst, const void *src1, const void *src2,
          size_t size) {
  sycl::buffer<char> buf_dst(static_cast<char *>(dst), sycl::range<1>(size));
  sycl::buffer<char> buf_src1(static_cast<const char *>(src1),
                              sycl::range<1>(size));
  sycl::buffer<char> buf_src2(static_cast<const char *>(src2),
                              sycl::range<1>(size));
  q.submit([&buf_dst, &buf_src1, &buf_src2, &size](sycl::handler &h) {
    sycl::accessor a(buf_src1, h, sycl::read_only);
    sycl::accessor b(buf_src2, h, sycl::read_only);
    sycl::accessor c(buf_dst, h, sycl::write_only, sycl::no_init);
    h.parallel_for(sycl::range<1>(size), [=](auto i) { c[i] = a[i] + b[i]; });
  });
  q.wait();
}

int main() {
  sycl::queue queue;
  std::vector<int> a(1024, 1), b(1024, 2), c(1024, 0);
  vadd(queue, c.data(), a.data(), b.data(), a.size() * sizeof(int));
  for (auto &e : c) {
    if (e != 3) {
      std::cerr << "Error: vadd failed, expected 3 but got " << e << std::endl;
      return 1;
    }
  }
  std::cout << "Success!\n";
  return 0;
}
