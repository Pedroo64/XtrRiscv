# Makefile
INIT_FILE ?= "none"
OUTPUT_FILE ?= "none"
ROOT_DIR =$(PWD)/../..

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

VHDL_SOURCES += $(ROOT_DIR)/cpu/alu_pkg.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/alu.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/rv32i_pkg.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/csr_def.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/instruction_fetch.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/instruction_decode.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/execute.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/memory.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/writeback.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/csr.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/regfile.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/control_unit.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/interrupt_handler.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/cpu.vhd
VHDL_SOURCES += $(ROOT_DIR)/utils/utils.vhd
VHDL_SOURCES += $(ROOT_DIR)/utils/xtr_def.vhd
VHDL_SOURCES += $(ROOT_DIR)/utils/xtr_abr.vhd
VHDL_SOURCES += $(ROOT_DIR)/utils/data_handshake.vhd
VHDL_SOURCES += $(ROOT_DIR)/cpu/xtr_cpu.vhd
VHDL_SOURCES += $(ROOT_DIR)/soc/ram/ghdl/bram.vhd
VHDL_SOURCES += $(ROOT_DIR)/soc/ram/xtr_ram.vhd
VHDL_SOURCES += $(ROOT_DIR)/testbenches/src/sim_stdout.vhd
VHDL_SOURCES += $(ROOT_DIR)/testbenches/src/sim_file.vhd
VHDL_SOURCES += $(ROOT_DIR)/testbenches/src/sim_soc.vhd
VHDL_SOURCES += $(ROOT_DIR)/testbenches/tb_xtr_soc.vhd
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb_xtr_soc

# MODULE is the basename of the Python test file
MODULE = main

SIM_ARGS += -gC_INIT_FILE=$(INIT_FILE)
SIM_ARGS += -gC_OUTPUT_FILE=$(OUTPUT_FILE)
SIM_ARGS += --ieee-asserts=disable
# SIM_ARGS += --vcd=waveform.vcd
EXTRA_ARGS += -fsynopsys

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
