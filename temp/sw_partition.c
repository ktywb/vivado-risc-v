#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
//#include "inputData.h"
//#include "inputInfos.h"
#include "dataset.h"
// #include "config.h"
#include <stddef.h>
#include <time.h>
#include <errno.h>

#include "riscv_timing.h"

// Parameter Define
#define MAX_TUPLE_LEN 32
#define PARTITION_NUM 8
#define SEED 42
#define STD_LOG_FILE "./sw_partition_log.txt"
#define STD_FILE "./sw_partition_output.txt"

// static inline unsigned long long get_cycles() {
//     struct timespec ts;
//     clock_gettime(CLOCK_MONOTONIC, &ts);
//     return (unsigned long long)ts.tv_sec * 1000000000 + ts.tv_nsec;
// }



static inline struct timespec get_time_spec(void) {
    struct timespec ts = {0, 0};
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        perror("clock_gettime failed");
    }
    return ts;
}

static inline unsigned long long timespec_to_ns(struct timespec ts) {
    return (unsigned long long)ts.tv_sec * 1000000000ULL
         + (unsigned long long)ts.tv_nsec;
}

static inline unsigned long long timespec_diff_ns(struct timespec t1, struct timespec t0) {
    long sec  = t1.tv_sec  - t0.tv_sec;
    long nsec = t1.tv_nsec - t0.tv_nsec;
    if (nsec < 0) { --sec; nsec += 1000000000L; }
    return (unsigned long long)sec * 1000000000ULL + (unsigned long long)nsec;
}

/* 旋转操作 */
static inline uint32_t rotl32(uint32_t x, int8_t r) {
    return (x << r) | (x >> (32 - r));
}

/* MurmurHash3的核心混洗函数 */
static uint32_t fmix32(uint32_t h) {
    h ^= h >> 16;
    h *= 0x85EBCA6B;
    h ^= h >> 13;
    h *= 0xC2B2AE35;
    h ^= h >> 16;
    return h;
}

/* MurmurHash3 32位实现 */
uint32_t MurmurHash3(const uint8_t* key, size_t len, uint32_t seed) {
    const uint32_t nblocks = len / 4;
    uint32_t h1 = seed;
    
    const uint32_t c1 = 0xCC9E2D51;
    const uint32_t c2 = 0x1B873593;
    
    /* 处理4字节块 */
    const uint32_t* blocks = (const uint32_t*)(key + nblocks * 4);
    for (int i = -(int)nblocks; i; i++) {
        uint32_t k1 = blocks[i];
        k1 *= c1;
        k1 = rotl32(k1, 15);
        k1 *= c2;
        h1 ^= k1;
        h1 = rotl32(h1, 13);
        h1 = h1 * 5 + 0xE6546B64;
    }
    
    /* 处理剩余字节 */
    const uint8_t* tail = key + nblocks * 4;
    uint32_t k1 = 0;
    
    switch (len & 3) {
        case 3:
            k1 ^= tail[2] << 16;
            /* fall through */
        case 2:
            k1 ^= tail[1] << 8;
            /* fall through */
        case 1:
            k1 ^= tail[0];
            k1 *= c1;
            k1 = rotl32(k1, 15);
            k1 *= c2;
            h1 ^= k1;
            h1 = rotl32(h1, 13);
            h1 = h1 * 5 + 0xE6546B64;
                }
    
    h1 ^= len;
    h1 = fmix32(h1);
    
    return h1;
}

typedef struct {
    char tplue_str[MAX_TUPLE_LEN*2 + 1]; // 2 hex chars + end tag
} TupleStr;

typedef struct {
    TupleStr* tuples;
    size_t count;
    size_t capacity;
}PartitionBuf;

void init_partition(PartitionBuf* p){
    p -> capacity = 32;
    p -> count = 0;
    p -> tuples = (TupleStr*) malloc(sizeof(TupleStr) * (p -> capacity));
}

void add_to_partition(PartitionBuf* p, const char* tuple_str){
    if (p-> count >= p-> capacity){
        p -> capacity = p -> capacity * 2;
        p -> tuples = (TupleStr*) realloc(p->tuples, sizeof(TupleStr) * (p -> capacity));
    }

    strcpy(p-> tuples[p->count].tplue_str, tuple_str);
    p -> count += 1;
}

void free_partition(PartitionBuf* p) {
    free(p->tuples);
}

void to_hex(const uint8_t* data, int len, char* output){
    char* ptr = output;
    for (int i = len - 1; i >= 0; i--) {
        sprintf(ptr, "%02x", data[i]);
        ptr += 2;
    }
    *ptr = '\0';
}
int compare_tuples(const void* a, const void* b) {
    return strcmp(((TupleStr*)a)->tplue_str, ((TupleStr*)b)->tplue_str);
}


void sort_and_deduplicate(PartitionBuf* p) {
    if (p->count == 0) return;
    
    qsort(p->tuples, p->count, sizeof(TupleStr), compare_tuples);

    int write_pos = 0;
    for (int read_pos = 0; read_pos < p->count; read_pos++) {
        if (read_pos == 0 || strcmp(p->tuples[read_pos].tplue_str, p->tuples[write_pos - 1].tplue_str) != 0) {
            if (read_pos != write_pos) {
                strcpy(p->tuples[write_pos].tplue_str, p->tuples[read_pos].tplue_str);
            }
            write_pos++;
        }
    }
    p->count = write_pos;
}

int main(){
    size_t input_data_file_size = inputData_bin_len;
    PartitionBuf partitions[PARTITION_NUM];
    
    // FILE* logfile = fopen(STD_LOG_FILE, "w");
    // if (!logfile) {
    //     fprintf(stderr, "Failed to open log file: %s\n", STD_LOG_FILE);
    //     return 1;
    // }
    // uint64_t start_cycle = rdcycle();

    int iter = 20;
    int extra_iter = 2;
    int total_iter = iter + extra_iter;
    uint64_t cycles_array[total_iter];
    double time_array[total_iter];

    for (int i=0; i< PARTITION_NUM; i++){
        init_partition(&partitions[i]);
    }

    // printf("Input Info Size: %zu bytes\n", inputInfos_bin_len);
    // printf("Input Data Size: %zu bytes\n", inputData_bin_len);
    // printf("Start\n");

    for(int j=0;j<total_iter;j++){
        for (int i=0; i< PARTITION_NUM; i++){
            partitions[i].count = 0;
        }
        timing_t start = timing_start();
        size_t data_offset = 0;
        int tuple_count = 0;
        int info_count = sizeof(inputInfos_bin) / 4;

        for (int i = 0; i < info_count; i++){
            uint8_t tuple_len  = inputInfos_bin[i*4];
            uint8_t key_offset = inputInfos_bin[i*4 + 1];
            uint8_t key_len    = inputInfos_bin[i*4 + 2];

    //        printf("Processing tuple %d\t: key_offset=%d, key_len=%d, tuple_len=%d, ", i, key_offset, key_len, tuple_len);
            if (data_offset + tuple_len > sizeof(inputData_bin)){
                // printf("Error: Data offset exceeds input data size.\n");
                break;
            }

            const uint8_t* tuple_data = &inputData_bin[data_offset];
            if (key_offset + key_len > tuple_len) {
                fprintf(stderr, "Invalid key parameters at tuple %d: offset=%d, len=%d, tuple_len=%d\n",
                        tuple_count, key_offset, key_len, tuple_len);
                data_offset += tuple_len;
                continue;
            }

            // const uint8_t* key_data = &tuple_data[key_offset];
            const uint8_t* key_data = tuple_data + key_offset;
            uint32_t hash_val = MurmurHash3(key_data, key_len, SEED);
            int partition = hash_val & (PARTITION_NUM - 1);
    //      printf("Hash Value: %u, Partition: %u\n", hash_val, partition);

            char tuple_str[MAX_TUPLE_LEN*2 + 1];
            char key_str[MAX_TUPLE_LEN*2 + 1];
            to_hex(tuple_data, tuple_len, tuple_str);
            to_hex(key_data, key_len, key_str);

            add_to_partition(&partitions[partition], tuple_str);

            // fprintf(logfile, "Tuple %d: Key=%s, Hash=%u, Partition=%u, Tuple=%s\n",
            //         tuple_count, key_str, hash_val, partition, tuple_str);

            data_offset += tuple_len;
            tuple_count += 1;
        }
        // fclose(logfile);
        // for (int i = 0; i < PARTITION_NUM; i++) sort_and_deduplicate(&partitions[i]);
        // FILE* stdfile = fopen(STD_FILE, "w");
        // if (!stdfile) {
        //     fprintf(stderr, "Failed to open output file: %s\n", STD_FILE);
        //     return 1;
        // }
        // for (int i = 0; i < PARTITION_NUM; i++) {
        //     fprintf(stdfile, "=== Partition %d: %zu tuples ===\n", i, partitions[i].count);
        //     for (size_t j = 0; j < partitions[i].count; j++) {
        //         fprintf(stdfile, "%s\n", partitions[i].tuples[j].tplue_str);
        //     }
        // }
        // fclose(stdfile);

        // uint64_t end_cycle = rdcycle();
        uint64_t total_cycles = timing_get_cycles(start);
        double elapsed_ms = timing_get_ms(start);
        cycles_array[j] = total_cycles;
        time_array[j] = elapsed_ms;
        // printf("Iteration %d finished: cycles = %llu, time = %.3f ms\n", j+1, total_cycles, elapsed_ms);
    }


    for (int i = 0; i < PARTITION_NUM; i++) free_partition(&partitions[i]);
    // printf("Processed %d tuples\n", tuple_count);
    // printf("cycle:    %llu -> %llu (delta %llu)\n",
    //        (unsigned long long)start_cycle, (unsigned long long)end_cycle,
    //        (unsigned long long)(end_cycle - start_cycle));
    uint64_t cycles_min = cycles_array[0], cycles_max = cycles_array[0];
    for (int i = 1; i < total_iter; i++) {
        if (cycles_array[i] < cycles_min) cycles_min = cycles_array[i];
        if (cycles_array[i] > cycles_max) cycles_max = cycles_array[i];
    }
    double time_min = time_array[0], time_max = time_array[0];
    for (int i = 1; i < total_iter; i++) {
        if (time_array[i] < time_min) time_min = time_array[i];
        if (time_array[i] > time_max) time_max = time_array[i];
    }

    uint64_t cycles_sum = 0;
    double time_sum = 0.0;
    for (int i = 0; i < total_iter; i++) {
        if (cycles_array[i] != cycles_min && cycles_array[i] != cycles_max) {
        cycles_sum += cycles_array[i];
        }
        if (time_array[i] != time_min && time_array[i] != time_max) {
        time_sum += time_array[i];
        }
    }
  
    uint64_t cycles_ava = cycles_sum / iter;
    double time_ava = time_sum / iter;

    // printf("\n--- Raw Data ---\n");
    // printf("Cycles - Min: %llu, Max: %llu\n", cycles_min, cycles_max);
    // printf("Time   - Min: %.3f ms, Max: %.3f ms\n", time_min, time_max);

    // printf("\n\n========= Performance ==========\n");
    printf("Cycles:%llu|", cycles_ava);
    printf("Time(ms):%.3f|", time_ava);
    printf("Throughput(MB/s):%.2f\n", (input_data_file_size / 1024.0 / 1024.0) / (time_ava / 1000.0));
    // printf("================================\n\n");
    return 0;
}


// #include <stdio.h>
// #include <stdlib.h>
// #include <stdint.h>
// #include <string.h>
// //#include "inputData.h"
// //#include "inputInfos.h"
// #include "dataset.h"
// // #include "config.h"
// #include <stddef.h>
// #include <time.h>
// #include <errno.h>

// // Parameter Define
// #define MAX_TUPLE_LEN 32
// #define PARTITION_NUM 8
// #define SEED 42
// #define STD_LOG_FILE "./sw_partition_log.txt"
// #define STD_FILE "./sw_partition_output.txt"

// // static inline unsigned long long get_cycles() {
// //     struct timespec ts;
// //     clock_gettime(CLOCK_MONOTONIC, &ts);
// //     return (unsigned long long)ts.tv_sec * 1000000000 + ts.tv_nsec;
// // }



// static inline struct timespec get_time_spec(void) {
//     struct timespec ts = {0, 0};
//     if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
//         perror("clock_gettime failed");
//     }
//     return ts;
// }

// static inline unsigned long long timespec_to_ns(struct timespec ts) {
//     return (unsigned long long)ts.tv_sec * 1000000000ULL
//          + (unsigned long long)ts.tv_nsec;
// }

// static inline unsigned long long timespec_diff_ns(struct timespec t1, struct timespec t0) {
//     long sec  = t1.tv_sec  - t0.tv_sec;
//     long nsec = t1.tv_nsec - t0.tv_nsec;
//     if (nsec < 0) { --sec; nsec += 1000000000L; }
//     return (unsigned long long)sec * 1000000000ULL + (unsigned long long)nsec;
// }

// static inline uint64_t rdcycle(void) {
//     uint64_t v;
//     __asm__ volatile ("rdcycle %0" : "=r"(v));
//     return v;
// }



// /* 旋转操作 */
// static inline uint32_t rotl32(uint32_t x, int8_t r) {
//     return (x << r) | (x >> (32 - r));
// }

// /* MurmurHash3的核心混洗函数 */
// static uint32_t fmix32(uint32_t h) {
//     h ^= h >> 16;
//     h *= 0x85EBCA6B;
//     h ^= h >> 13;
//     h *= 0xC2B2AE35;
//     h ^= h >> 16;
//     return h;
// }

// /* MurmurHash3 32位实现 */
// uint32_t MurmurHash3(const uint8_t* key, size_t len, uint32_t seed) {
//     const uint32_t nblocks = len / 4;
//     uint32_t h1 = seed;
    
//     const uint32_t c1 = 0xCC9E2D51;
//     const uint32_t c2 = 0x1B873593;
    
//     /* 处理4字节块 */
//     const uint32_t* blocks = (const uint32_t*)(key + nblocks * 4);
//     for (int i = -(int)nblocks; i; i++) {
//         uint32_t k1 = blocks[i];
//         k1 *= c1;
//         k1 = rotl32(k1, 15);
//         k1 *= c2;
//         h1 ^= k1;
//         h1 = rotl32(h1, 13);
//         h1 = h1 * 5 + 0xE6546B64;
//     }
    
//     /* 处理剩余字节 */
//     const uint8_t* tail = key + nblocks * 4;
//     uint32_t k1 = 0;
    
//     switch (len & 3) {
//         case 3:
//             k1 ^= tail[2] << 16;
//             /* fall through */
//         case 2:
//             k1 ^= tail[1] << 8;
//             /* fall through */
//         case 1:
//             k1 ^= tail[0];
//             k1 *= c1;
//             k1 = rotl32(k1, 15);
//             k1 *= c2;
//             h1 ^= k1;
//             h1 = rotl32(h1, 13);
//             h1 = h1 * 5 + 0xE6546B64;
//                 }
    
//     h1 ^= len;
//     h1 = fmix32(h1);
    
//     return h1;
// }

// typedef struct {
//     char tplue_str[MAX_TUPLE_LEN*2 + 1]; // 2 hex chars + end tag
// } TupleStr;

// typedef struct {
//     TupleStr* tuples;
//     size_t count;
//     size_t capacity;
// }PartitionBuf;

// void init_partition(PartitionBuf* p){
//     p -> capacity = 32;
//     p -> count = 0;
//     p -> tuples = (TupleStr*) malloc(sizeof(TupleStr) * (p -> capacity));
// }

// void add_to_partition(PartitionBuf* p, const char* tuple_str){
//     if (p-> count >= p-> capacity){
//         p -> capacity = p -> capacity * 2;
//         p -> tuples = (TupleStr*) realloc(p->tuples, sizeof(TupleStr) * (p -> capacity));
//     }

//     strcpy(p-> tuples[p->count].tplue_str, tuple_str);
//     p -> count += 1;
// }

// void free_partition(PartitionBuf* p) {
//     free(p->tuples);
// }

// void to_hex(const uint8_t* data, int len, char* output){
//     char* ptr = output;
//     for (int i = len - 1; i >= 0; i--) {
//         sprintf(ptr, "%02x", data[i]);
//         ptr += 2;
//     }
//     *ptr = '\0';
// }
// int compare_tuples(const void* a, const void* b) {
//     return strcmp(((TupleStr*)a)->tplue_str, ((TupleStr*)b)->tplue_str);
// }


// void sort_and_deduplicate(PartitionBuf* p) {
//     if (p->count == 0) return;
    
//     qsort(p->tuples, p->count, sizeof(TupleStr), compare_tuples);

//     int write_pos = 0;
//     for (int read_pos = 0; read_pos < p->count; read_pos++) {
//         if (read_pos == 0 || strcmp(p->tuples[read_pos].tplue_str, p->tuples[write_pos - 1].tplue_str) != 0) {
//             if (read_pos != write_pos) {
//                 strcpy(p->tuples[write_pos].tplue_str, p->tuples[read_pos].tplue_str);
//             }
//             write_pos++;
//         }
//     }
//     p->count = write_pos;
// }

// int main(){
//     PartitionBuf partitions[PARTITION_NUM];
//     for (int i=0; i< PARTITION_NUM; i++){
//         init_partition(&partitions[i]);
//     }
//     FILE* logfile = fopen(STD_LOG_FILE, "w");
//     if (!logfile) {
//         fprintf(stderr, "Failed to open log file: %s\n", STD_LOG_FILE);
//         return 1;
//     }
//     uint64_t start_cycle = rdcycle();
//     size_t data_offset = 0;
//     int tuple_count = 0;
//     int info_count = sizeof(inputInfos_bin) / 4;

//     for (int i = 0; i < info_count; i++){
//         uint8_t tuple_len  = inputInfos_bin[i*4];
//         uint8_t key_offset = inputInfos_bin[i*4 + 1];
//         uint8_t key_len    = inputInfos_bin[i*4 + 2];

// //        printf("Processing tuple %d\t: key_offset=%d, key_len=%d, tuple_len=%d, ", i, key_offset, key_len, tuple_len);
//         if (data_offset + tuple_len > sizeof(inputData_bin)){
//             printf("Error: Data offset exceeds input data size.\n");
//             break;
//         }

//         const uint8_t* tuple_data = &inputData_bin[data_offset];
//         if (key_offset + key_len > tuple_len) {
//             fprintf(stderr, "Invalid key parameters at tuple %d: offset=%d, len=%d, tuple_len=%d\n",
//                     tuple_count, key_offset, key_len, tuple_len);
//             data_offset += tuple_len;
//             continue;
//         }

//         // const uint8_t* key_data = &tuple_data[key_offset];
//         const uint8_t* key_data = tuple_data + key_offset;
//         uint32_t hash_val = MurmurHash3(key_data, key_len, SEED);
//         int partition = hash_val & (PARTITION_NUM - 1);
//   //      printf("Hash Value: %u, Partition: %u\n", hash_val, partition);

//         char tuple_str[MAX_TUPLE_LEN*2 + 1];
//         char key_str[MAX_TUPLE_LEN*2 + 1];
//         to_hex(tuple_data, tuple_len, tuple_str);
//         to_hex(key_data, key_len, key_str);

//         add_to_partition(&partitions[partition], tuple_str);

//         fprintf(logfile, "Tuple %d: Key=%s, Hash=%u, Partition=%u, Tuple=%s\n",
//                 tuple_count, key_str, hash_val, partition, tuple_str);

//         data_offset += tuple_len;
//         tuple_count += 1;
//     }
//     fclose(logfile);
//     for (int i = 0; i < PARTITION_NUM; i++) sort_and_deduplicate(&partitions[i]);
//     FILE* stdfile = fopen(STD_FILE, "w");
//     if (!stdfile) {
//         fprintf(stderr, "Failed to open output file: %s\n", STD_FILE);
//         return 1;
//     }
//     for (int i = 0; i < PARTITION_NUM; i++) {
//         fprintf(stdfile, "=== Partition %d: %zu tuples ===\n", i, partitions[i].count);
//         for (size_t j = 0; j < partitions[i].count; j++) {
//             fprintf(stdfile, "%s\n", partitions[i].tuples[j].tplue_str);
//         }
//     }
//     fclose(stdfile);
//     uint64_t end_cycle = rdcycle();
//     for (int i = 0; i < PARTITION_NUM; i++) free_partition(&partitions[i]);
//     printf("Processed %d tuples\n", tuple_count);
//     printf("cycle:    %llu -> %llu (delta %llu)\n",
//            (unsigned long long)start_cycle, (unsigned long long)end_cycle,
//            (unsigned long long)(end_cycle - start_cycle));
//     return 0;
// }

