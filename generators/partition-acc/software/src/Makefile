RISCV_PFX=riscv64-unknown-elf-
RISCV_CC=$(RISCV_PFX)gcc
RISCV_OBJDUMP=$(RISCV_PFX)objdump

CC=gcc

BINARY_OPT=-static -specs=htif_nano.specs
OBJECT_DUMP_OPT=--disassemble-all

# --- Header Generation ---
HEADER_FILE=partition_data.h
HEADER_DEPS=../data/cache_line.mem ../data/tuple_length.mem ../data/key.mem generate_arrays.py

$(HEADER_FILE): $(HEADER_DEPS)
		python generate_arrays.py

# --- RoCC Target ---
TARGET=partition-rocc
TARGET_RISCV=$(TARGET).riscv
TARGET_OBJDUMP=$(TARGET).riscv.dump
TARGET_DEPS=partition-rocc.c $(HEADER_FILE) # Added header dependency
JUNK += $(TARGET_RISCV) $(TARGET_OBJDUMP) $(HEADER_FILE) # Added header to JUNK

rocc: $(TARGET_RISCV) $(TARGET_OBJDUMP)

$(TARGET_RISCV): $(TARGET_DEPS)
		$(RISCV_CC) $(BINARY_OPT) -o $@ partition-rocc.c # Compile only the C file

$(TARGET_OBJDUMP): $(TARGET_RISCV)
		$(RISCV_OBJDUMP) $(OBJECT_DUMP_OPT) $< > $@

# --- Non-RoCC (Origin) Target ---
NOROCC_TARGET=partition
NOROCC_TARGET_RISCV=$(NOROCC_TARGET).riscv
NOROCC_TARGET_OBJDUMP=$(NOROCC_TARGET).riscv.dump
NOROCC_SRCS=partition.c murmurhash.c# Source files
NOROCC_TARGET_DEPS=$(NOROCC_SRCS) $(HEADER_FILE) # Added header dependency
JUNK += $(NOROCC_TARGET_RISCV) $(NOROCC_TARGET_OBJDUMP)

origin: $(NOROCC_TARGET_RISCV) $(NOROCC_TARGET_OBJDUMP)

$(NOROCC_TARGET_RISCV): $(NOROCC_TARGET_DEPS)
		$(RISCV_CC) $(BINARY_OPT) -o $@ $(NOROCC_SRCS) # Compile source files

$(NOROCC_TARGET_OBJDUMP): $(NOROCC_TARGET_RISCV)
		$(RISCV_OBJDUMP) $(OBJECT_DUMP_OPT) $< > $@

# --- Native Target (Review if still valid) ---
# If partition.c uses rdcycle, this target will likely fail.
# Consider removing it or modifying partition.c with #ifdefs.
NATIVE_TARGET=partition-native
NATIVE_SRCS=partition.c murmurhash.c # Source files
# NATIVE_TARGET_DEPS=$(NATIVE_SRCS) $(HEADER_FILE) # Add header dependency if needed
NATIVE_TARGET_DEPS=$(NATIVE_SRCS)
JUNK += $(NATIVE_TARGET)

native: $(NATIVE_TARGET)

$(NATIVE_TARGET): $(NATIVE_TARGET_DEPS)
		$(CC) -o $@ $(NATIVE_SRCS) # Compile source files

# --- Meta Targets ---
all: rocc origin # Removed native for now, assuming it's broken

# --- Cleanup ---
clean:
		rm -f $(JUNK)

# --- Phony Targets ---
.PHONY: all rocc origin native clean data # Added phony targets

# Optional target to explicitly generate data
data: $(HEADER_FILE)
