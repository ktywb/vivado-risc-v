OPTIMIZATION = -O0
# INCLUDE_DIR = ./benchmark-dhrystone

# define desired dhrystone iterations
# NOTE: this needs to be a large number to make dhrystone happy enough for an accurate result
# TEST_SPECIFIC_FLAGS = -Dprintf=kprintf -DMSC_CLOCK

SRCS = head.S main.c 
# time_override.c

run:
	../scripts/*.sh

include ../common.mk
