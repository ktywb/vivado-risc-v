#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __riscv
#include <sys/time.h>
#else
#include <time.h>
#include <x86intrin.h>
#endif

#include "encoding.h"  // For rdcycle

// --- Include the generated header ---
#include "partition_data.h"

// Global constants (can be kept or removed if defined elsewhere)
int HASH_WIDTH = 12;
int PARTITION_NUM = 8;
int SEED = 258794175;

// --- Declaration for MurmurHash3 (implementation assumed elsewhere) ---
// Note: Ensure the C implementation of MurmurHash3 exists and is linked.
uint32_t MurmurHash3(const uint8_t* key, size_t len, uint32_t seed);

// --- Helper function to get cycles/time ---
static inline unsigned long long get_cycles() {
#ifdef __riscv
  return rdcycle();
#else
  // Use host's monotonic clock (example using clock_gettime)
  // This gives nanoseconds, not cycles, but provides a time measurement
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (unsigned long long)ts.tv_sec * 1000000000 + ts.tv_nsec;
  // Alternatively, return 0 if host timing is not needed
  // return 0;
#endif
}

static inline unsigned long long get_instructions() {
#ifdef __riscv
  return rdinstret();
#else
  unsigned int counter_index = 0;  // 选择计数器 0
  return __rdpmc(counter_index);
#endif
}

int main(int argc, char* argv[]) {
  // --- Partition data structure (simplified to counts) ---
  int partition_counts[PARTITION_NUM];
  for (int i = 0; i < PARTITION_NUM; ++i) {
    partition_counts[i] = 0;
  }

  int tuple_index = 0;  // Counter for tuples processed

  // --- Pointers to navigate embedded data ---
  const uint8_t* current_tuple_ptr = cache_line_data;
  const uint8_t* current_len_ptr = tuple_length_data;
  const uint8_t* current_key_info_ptr = key_info_data;

  // --- Pointers to the end of the control data arrays ---
  const uint8_t* const end_len_ptr = tuple_length_data + tuple_length_data_size;
  const uint8_t* const end_key_info_ptr = key_info_data + key_info_data_size;
  const uint8_t* const end_cache_line_ptr =
      cache_line_data + cache_line_data_size;

  printf("main() started - Using embedded data for software partition\n");
  printf("  Cache Line Size: %lu bytes\n", cache_line_data_size);
  printf("  Tuple Length Size: %lu bytes\n", tuple_length_data_size);
  printf("  Key Info Size: %lu bytes\n", key_info_data_size);

  // --- Cycle Measurement Start ---
  unsigned long long start_cycle = get_cycles();

  // --- Processing Loop using embedded data ---
  while (current_len_ptr < end_len_ptr &&
         current_key_info_ptr < end_key_info_ptr) {
    int tuple_length = (int)(*current_len_ptr);
    current_len_ptr++;
    int key_length = (int)(*current_key_info_ptr);
    current_key_info_ptr++;
    int key_offset = (int)(*current_key_info_ptr);
    current_key_info_ptr++;
    const uint8_t* key = current_tuple_ptr + key_offset;

    // --- Hashing and Partitioning ---
    uint32_t hash = MurmurHash3(key, key_length, SEED);
    uint32_t masked_hash = hash & ((1 << HASH_WIDTH) - 1);
    uint32_t which_partition = masked_hash % PARTITION_NUM;
    partition_counts[which_partition]++;

    current_tuple_ptr += tuple_length;
    tuple_index++;
  }

  // --- Cycle Measurement End ---
  unsigned long long end_cycle = get_cycles();

  // --- Final Checks (Optional) ---
  // if (current_len_ptr != end_len_ptr) {
  //   fprintf(stderr, "Warning: Did not consume all tuple length data.\n");
  // }
  // if (current_key_info_ptr != end_key_info_ptr) {
  //   fprintf(stderr, "Warning: Did not consume all key info data.\n");
  // }
  // if (current_tuple_ptr != end_cache_line_ptr) {
  //   fprintf(stderr, "Warning: Did not consume all cache line data.\n");
  // }

  unsigned long long cycle_diff = end_cycle - start_cycle;
  unsigned int cycle_high = (unsigned int)(cycle_diff >> 32);
  unsigned int cycle_low = (unsigned int)(cycle_diff & 0xFFFFFFFF);

  printf("Finished processing %d tuples (Software).\n", tuple_index);
  if (cycle_high > 0) {
    printf("Software Execution Cycles: 0x%x%08x\n", cycle_high, cycle_low);
  } else {
    printf("Software Execution Cycles: 0x%x\n", cycle_low);
  }

  for (int i = 0; i < PARTITION_NUM; ++i) {
    printf("Partition %d count: %d\n", i, partition_counts[i]);
  }

cleanup:  // Label for potential error jumps
  // --- No files to close ---

  return 0;  // Or return an error code if cleanup was reached due to error
}
