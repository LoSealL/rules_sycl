#include "cstdio"

#define TO_STRING_IND(X) #X
#define TO_STRING(X) TO_STRING_IND(X)

int main(int argc, char* argv[]) {
    std::printf("ERROR: " TO_STRING(TOOLNAME) " of sycl toolkit does not exist\n");
    return -1;
}
