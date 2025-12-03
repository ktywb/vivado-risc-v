OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
  memory_mem (rwx) : ORIGIN = 0x80000000, LENGTH = 0x40000000 /*0x1000000*/
}

PHDRS {
  text PT_LOAD;
  data PT_LOAD;
}

SECTIONS {
  PROVIDE(_ram = ORIGIN(memory_mem));
  PROVIDE(_ram_end = _ram + LENGTH(memory_mem));

  .text : {
    . += 8; /* Trap vector */
    PROVIDE(_ftext = .);
    *(.text.unlikely .text.unlikely.*)
    *(.text .text.* .gnu.linkonce.t.*)
    . = ALIGN(8);
    PROVIDE(_etext = .);
    *(.eh_frame)
    /* . = ALIGN(4096);  添加这行：4KB 对齐 */
    *(.rodata .rodata.* .gnu.linkonce.r.*)
    *(.srodata .srodata.*)
  } >memory_mem  :text

  .data : {
    /* . = ALIGN(4096);  添加这行 */
    *(.data .data.* .gnu.linkonce.d.*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    *(.tohost)
  } >memory_mem  :data

  .bss : {
    PROVIDE(_fbss = .);
    PROVIDE(__global_pointer$ = . + 0x7C0);
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.bss .bss.* .gnu.linkonce.b.*)
    . = ALIGN(8);
    PROVIDE(_ebss = .);
    PROVIDE(_end = .);  /* Required for _sbrk */

    PROVIDE(_heap_start = .);
    PROVIDE(_heap_end = _ram + 0x30000000);  /* 预留 768MB 堆 (可根据需要调整) */
  } >memory_mem

  PROVIDE(_stack_end = _ram_end - 0x100000);   /* 栈底，预留 1MB 栈 */
  PROVIDE(_stack_start = _ram_end);            /* 栈顶 */

  .note (INFO) : {
    *(.note .note.*)
  }

  
}
