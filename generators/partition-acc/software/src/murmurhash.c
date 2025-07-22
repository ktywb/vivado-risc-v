#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Note: C standard doesn't guarantee inline expansion, but it's a hint.
// static inline is often used for functions defined in headers or local to a
// file.
static inline uint32_t rotl32(uint32_t x, int8_t r) {
  return (x << r) | (x >> (32 - r));
}

// MurmurHash3's core mix function
static uint32_t fmix32(uint32_t h) {
  h ^= h >> 16;
  h *= 0x85EBCA6B;
  h ^= h >> 13;
  h *= 0xC2B2AE35;
  h ^= h >> 16;
  return h;
}

// MurmurHash3 function (x86_32)
// Changed input from const uint32_t* to const uint8_t* as in the C++ version
uint32_t MurmurHash3(const uint8_t* key, size_t len, uint32_t seed) {
  const uint32_t nblocks = len / 4;
  uint32_t h1 = seed;

  const uint32_t c1 = 0xCC9E2D51;
  const uint32_t c2 = 0x1B873593;

  // Body - process 4-byte blocks
  // C-style cast instead of reinterpret_cast
  const uint32_t* blocks = (const uint32_t*)(key + nblocks * 4);

  for (int i = -((int)nblocks); i; i++) {
    uint32_t k1 = blocks[i];  // Read block

    k1 *= c1;
    k1 = rotl32(k1, 15);
    k1 *= c2;

    h1 ^= k1;
    h1 = rotl32(h1, 13);
    h1 = h1 * 5 + 0xE6546B64;
  }

  // Tail - process remaining bytes
  const uint8_t* tail = (const uint8_t*)(key + nblocks * 4);
  uint32_t k1 = 0;

  switch (len & 3) {  // Check remaining bytes (0, 1, 2, or 3)
    case 3:
      k1 ^= ((uint32_t)tail[2]) << 16;
      /* fallthrough */  // Standard C comment for fallthrough
    case 2:
      k1 ^= ((uint32_t)tail[1]) << 8;
      /* fallthrough */
    case 1:
      k1 ^= ((uint32_t)tail[0]);
      k1 *= c1;
      k1 = rotl32(k1, 15);
      k1 *= c2;
      h1 ^= k1;
      // Note: The original C++ code had the final h1 update *inside* the switch
      // case 1. This seems unusual, typically it's outside. Let's keep it as is
      // to match the C++. If this was a mistake in the C++, it should be moved
      // outside the switch. h1 = rotl32(h1, 13); // Moved outside in typical
      // implementations h1 = h1 * 5 + 0xE6546B64; // Moved outside in typical
      // implementations
      break;  // Added break for clarity, though fallthrough handles it
  };

  // Finalization Mix
  // h1 ^= len; // This line is often present but missing in the provided C++
  h1 = fmix32(h1);

  return h1;
}