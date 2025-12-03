#ifndef _BOOT_COMMON_H
#define _BOOT_COMMON_H

// Memory layout for 1GB DRAM
// Base address: 0x80000000
// Size: 1GB (0x40000000)
// Stack at top of memory (grows down from 0xC0000000)
#define BOOT_MEM_ADDR    0x80000000
#define BOOT_MEM_END     0xC0000000  // Top of 1GB memory (was 0x81000000 for 16MB)

#endif
