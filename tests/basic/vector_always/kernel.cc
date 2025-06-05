#include "kernel.h"

void launch(int *a, int *b, int *c) {
  #pragma vector always
  for (int i = 0; i < 1024; i++) {
    c[i] = a[i] + b[i];
  }
}
