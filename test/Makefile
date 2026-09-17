# Makefile
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src

VERILOG_SOURCES += $(SRC_DIR)/tt_um_catalinlazar_nanopio.v
VERILOG_SOURCES += $(SRC_DIR)/nanopio_core.v
VERILOG_SOURCES += $(SRC_DIR)/nanopio_progmem.v
VERILOG_SOURCES += $(SRC_DIR)/nanopio_loader.v

COMPILE_ARGS += -I$(SRC_DIR)
COMPILE_ARGS += -DCOCOTB_SIM=1

TOPLEVEL = tt_um_catalinlazar_nanopio
MODULE = test

include $(shell cocotb-config --makefiles)/Makefile.sim
