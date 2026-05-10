#include <stdint.h>
#include <stdio.h>

int popcount(uint32_t n) {
    int count = 0;
    while (n) {
        count += n & 1;
        n >>= 1;
    }
    return count;
}

int leading_zeros(uint32_t n, int width) {
    if (n == 0) return width;
    int lz = 0;
    for (int i = width - 1; i >= 0; i--) {
        if (n & (1 << i)) {
            lz = width - 1 - i;
            break;
        }
    }
    return lz;
}

int hamming_distance(uint32_t x, uint32_t y) {
    return popcount(x ^ y);
}

uint32_t bit_reverse(uint32_t n, int width) {
    uint32_t result = 0;
    for (int i = 0; i < width; i++) {
        result = (result << 1) | (n & 1);
        n >>= 1;
    }
    return result;
}

int main() {
    printf("Popcount of 5: %d\n", popcount(5));
    printf("Leading zeros of 5: %d\n", leading_zeros(5, 32));
    printf("Hamming distance between 5 and 3: %d\n", hamming_distance(5, 3));
    printf("Bit reverse of 5 (8 bits): %u\n", bit_reverse(5, 8));
    return 0;
}