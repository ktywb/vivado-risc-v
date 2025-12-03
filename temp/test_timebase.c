#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>

// RISC-V CSR读取指令
static inline uint64_t rdcycle(void) {
    uint64_t cycles;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles));
    return cycles;
}

static inline uint64_t rdtime(void) {
    uint64_t time;
    __asm__ volatile ("rdtime %0" : "=r"(time));
    return time;
}

static inline uint64_t rdinstret(void) {
    uint64_t instret;
    __asm__ volatile ("rdinstret %0" : "=r"(instret));
    return instret;
}

int main() {
    printf("=== RISC-V Time Base Frequency Measurement ===\n\n");
    
    // 方法1: 通过sleep()测量rdtime的频率
    printf("Method 1: Measuring rdtime frequency via sleep()...\n");
    uint64_t time_start = rdtime();
    sleep(1);  // 睡眠1秒
    uint64_t time_end = rdtime();
    uint64_t time_delta = time_end - time_start;
    
    printf("  rdtime: %lu -> %lu\n", time_start, time_end);
    printf("  Delta after 1 second: %lu\n", time_delta);
    printf("  Estimated timebase-frequency: %lu Hz\n\n", time_delta);
    
    // 方法2: 通过clock_gettime()精确测量
    printf("Method 2: Measuring with clock_gettime()...\n");
    struct timespec ts_start, ts_end;
    
    clock_gettime(CLOCK_MONOTONIC, &ts_start);
    time_start = rdtime();
    
    usleep(100000);  // 睡眠100毫秒
    
    clock_gettime(CLOCK_MONOTONIC, &ts_end);
    time_end = rdtime();
    
    double wall_time_ns = (ts_end.tv_sec - ts_start.tv_sec) * 1e9 + 
                         (ts_end.tv_nsec - ts_start.tv_nsec);
    time_delta = time_end - time_start;
    
    double timebase_freq = (double)time_delta / (wall_time_ns / 1e9);
    
    printf("  Wall time: %.3f ms\n", wall_time_ns / 1e6);
    printf("  rdtime delta: %lu\n", time_delta);
    printf("  Calculated timebase-frequency: %.0f Hz\n\n", timebase_freq);
    
    // 方法3: 使用rdcycle和rdtime的比例来估算CPU频率
    printf("Method 3: Estimating CPU frequency from cycle/time ratio...\n");
    
    uint64_t cycle_start = rdcycle();
    time_start = rdtime();
    
    // 执行一些工作
    volatile long sum = 0;
    for (int i = 0; i < 10000000; i++) {
        sum += i;
    }
    
    uint64_t cycle_end = rdcycle();
    time_end = rdtime();
    
    uint64_t cycle_delta = cycle_end - cycle_start;
    time_delta = time_end - time_start;
    
    printf("  Cycles:  %lu\n", cycle_delta);
    printf("  rdtime:  %lu\n", time_delta);
    
    if (time_delta > 0) {
        double cycle_to_time_ratio = (double)cycle_delta / (double)time_delta;
        printf("  Cycle/Time ratio: %.2f\n", cycle_to_time_ratio);
        
        // 如果timebase是1MHz，那么CPU频率 = ratio * 1MHz
        printf("  If timebase=1MHz, CPU freq = %.2f MHz\n", cycle_to_time_ratio);
        printf("  If timebase=10MHz, CPU freq = %.2f MHz\n", cycle_to_time_ratio * 10);
        printf("  If timebase=32.768kHz, CPU freq = %.2f MHz\n", cycle_to_time_ratio * 0.032768);
    }
    
    printf("\n=== Summary ===\n");
    printf("To convert rdtime to actual time:\n");
    printf("  time_seconds = rdtime_delta / timebase_frequency\n");
    printf("  time_seconds = rdtime_delta / %lu\n\n", time_delta);
    
    printf("To estimate cycles from rdtime (if you know both frequencies):\n");
    printf("  estimated_cycles = rdtime_delta * (cpu_freq / timebase_freq)\n");
    
    return 0;
}
