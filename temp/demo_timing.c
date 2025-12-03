#include <stdio.h>
#include "riscv_timing.h"

int main() {
    printf("=== RISC-V Timing Utilities Demo ===\n\n");
    
    printf("System Configuration:\n");
    printf("  CPU Frequency:      %.1f MHz\n", CPU_FREQ_MHZ);
    printf("  Timebase Frequency: %u Hz (625 kHz)\n", TIMEBASE_FREQ_HZ);
    printf("  Cycles per tick:    %u\n\n", CYCLES_PER_TICK);
    
    // 示例1: 使用 rdtime 测量和估算周期数
    printf("Example 1: Measure with rdtime and estimate cycles\n");
    
    timing_t timer = timing_start();
    
    volatile long sum = 0;
    for (int i = 0; i < 1000000; i++) {
        sum += i;
    }
    
    uint64_t time_ticks = timing_get_ticks(timer);
    uint64_t estimated_cycles = timing_get_cycles(timer);
    double elapsed_ms = timing_get_ms(timer);
    
    printf("  Loop iterations:     1,000,000\n");
    printf("  rdtime ticks:        %lu\n", time_ticks);
    printf("  Elapsed time:        %.3f ms\n", elapsed_ms);
    printf("  Estimated cycles:    %lu\n", estimated_cycles);
    printf("  Cycles per iter:     %.2f\n\n", (double)estimated_cycles / 1000000.0);
    
    // 示例2: 使用函数快速测量
    printf("Example 2: Quick timing with helper functions\n");
    
    timer = timing_start();
    for (volatile int i = 0; i < 10000; i++);
    uint64_t cycles = timing_get_cycles(timer);
    
    timer = timing_start();
    for (volatile int i = 0; i < 10000; i++);
    double ms = timing_get_ms(timer);
    
    printf("  10,000 iterations:\n");
    printf("    Estimated cycles: %lu\n", cycles);
    printf("    Elapsed time:     %.3f ms\n\n", ms);
    
    // 示例3: 不同规模的计算
    printf("Example 3: Different workload sizes\n");
    
    int sizes[] = {100, 1000, 10000, 100000};
    for (int s = 0; s < 4; s++) {
        timer = timing_start();
        
        volatile long x = 0;
        for (int i = 0; i < sizes[s]; i++) {
            x += i;
        }
        
        uint64_t c = timing_get_cycles(timer);
        double t = rdtime_to_us(timing_get_ticks(timer));
        
        printf("  %6d iters: %8lu cycles, %8.2f us (%.2f cycles/iter)\n",
               sizes[s], c, t, (double)c / sizes[s]);
    }
    
    printf("\n=== Usage Summary ===\n\n");
    printf("方法1: 手动测量\n");
    printf("  uint64_t t1 = rdtime();\n");
    printf("  // ... your code ...\n");
    printf("  uint64_t t2 = rdtime();\n");
    printf("  uint64_t cycles = rdtime_to_cycles(t2 - t1);\n");
    printf("  double ms = rdtime_to_ms(t2 - t1);\n\n");
    
    printf("方法2: 使用辅助函数\n");
    printf("  timing_t timer = timing_start();\n");
    printf("  // ... your code ...\n");
    printf("  uint64_t cycles = timing_get_cycles(timer);\n");
    printf("  double ms = timing_get_ms(timer);\n\n");
    
    printf("关键公式:\n");
    printf("  estimated_cycles = rdtime_ticks * %d\n", CYCLES_PER_TICK);
    printf("  time_ms = rdtime_ticks * 1000.0 / %u\n", TIMEBASE_FREQ_HZ);
    
    return 0;
}
