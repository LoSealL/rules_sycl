#include "kernel.h"
#include <iostream>

int main() {
  int a[1024]{}, b[1024]{}, c[1024]{};
  for (int i = 0; i < 1024; i++) {
    a[i] = 1;
    b[i] = 2;
  }
  launch(a, b, c);
  bool success = true;
  for (int i = 0; i < 1024; i++) {
    if (c[i] != 3) {
      std::cerr << "Error: c[" << i << "] = " << c[i] << " instead of 3\n";
      success = false;
    }
  }
  std::cout << (success ? "Success!\n" : "Failure!\n");
  return 0;
}
