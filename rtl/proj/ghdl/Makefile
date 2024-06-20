ROOT_DIR = $(shell git rev-parse --show-toplevel)
GHDL  ?= ghdl
CMAKE ?= cmake

INIT_FILE               ?= none
OUTPUT_FILE             ?= none
EXECUTE_BYPASS          ?= true
MEMORY_BYPASS           ?= true
WRITEBACK_BYPASS        ?= true
REGFILE_BYPASS          ?= true
FULL_BARREL_SHIFTER     ?= true
SHIFTER_EARLY_INJECTION ?= true
EXTENSION_ZICSR         ?= true
EXTENSION_M             ?= true
EXTENSION_C             ?= true

RTL_DIR ?= $(ROOT_DIR)/rtl
VPI_DIR ?= $(RTL_DIR)/testbenches/src/vpi

TOP_LEVEL ?= tb_xtr_soc

VHDL_SOURCES += $(RTL_DIR)/utils/vhdl_utils.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/rv32i_pkg.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/csr_def.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/cpu_checker.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/utils/cpu_fifo.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/comparator.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/alu.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/c_extension/decompressor.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/m_extension/mul.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/m_extension/div.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/m_extension/muldiv.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/shifter.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/instruction_fetch.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/prefetch.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/instruction_decode.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/execute.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/memory.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/writeback.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/csr.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/regfile.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/control_unit.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/interrupt_handler.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/branch_unit.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/lsu.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/debug/dtm_pkg.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/debug/dtm_jtag.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/debug/debug_module_pkg.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/debug/debug_module.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/cpu.vhd
VHDL_SOURCES += $(RTL_DIR)/utils/utils.vhd
VHDL_SOURCES += $(RTL_DIR)/utils/xtr_def.vhd
VHDL_SOURCES += $(RTL_DIR)/utils/xtr_split.vhd
VHDL_SOURCES += $(RTL_DIR)/utils/data_handshake.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/xtr_cpu.vhd
VHDL_SOURCES += $(RTL_DIR)/soc/ram/ghdl/bram.vhd
VHDL_SOURCES += $(RTL_DIR)/soc/ram/xtr_ram.vhd
VHDL_SOURCES += $(RTL_DIR)/soc/timer/xtr_mtime.vhd
VHDL_SOURCES += $(RTL_DIR)/testbenches/src/sim_stdout.vhd
VHDL_SOURCES += $(RTL_DIR)/testbenches/src/sim_file.vhd
VHDL_SOURCES += $(RTL_DIR)/testbenches/src/sim_soc.vhd
VHDL_SOURCES += $(RTL_DIR)/testbenches/src/vpi/rtl/jtag_vpi.vhd
VHDL_SOURCES += $(RTL_DIR)/testbenches/tb_xtr_soc.vhd

BUILD_DIR=build

SIM_ARGS += -gG_INIT_FILE=$(INIT_FILE)
SIM_ARGS += -gG_OUTPUT_FILE=$(OUTPUT_FILE)
SIM_ARGS += -gG_EXECUTE_BYPASS=$(EXECUTE_BYPASS)
SIM_ARGS += -gG_MEMORY_BYPASS=$(MEMORY_BYPASS)
SIM_ARGS += -gG_WRITEBACK_BYPASS=$(WRITEBACK_BYPASS)
SIM_ARGS += -gG_REGFILE_BYPASS=$(REGFILE_BYPASS)
SIM_ARGS += -gG_FULL_BARREL_SHIFTER=$(FULL_BARREL_SHIFTER)
SIM_ARGS += -gG_SHIFTER_EARLY_INJECTION=$(SHIFTER_EARLY_INJECTION)
SIM_ARGS += -gG_EXTENSION_ZICSR=$(EXTENSION_ZICSR)
SIM_ARGS += -gG_EXTENSION_M=$(EXTENSION_M)
SIM_ARGS += -gG_EXTENSION_C=$(EXTENSION_C)
EXTRA_ARGS += -fsynopsys

RUN_ARGS += --vpi=$(VPI_DIR)/build/lib/libvpi.so

ifdef STOP_TIME
    STOP_TIME_ARG = --stop-time=$(STOP_TIME)
else
    STOP_TIME_ARG =
endif

import: $(BUILD_DIR) $(VHDL_SOURCES)
	$(GHDL) -i -fsynopsys --workdir=$(BUILD_DIR) $(VHDL_SOURCES)

unit: import vpi
	$(GHDL) -m -fsynopsys --workdir=$(BUILD_DIR) $(TOP_LEVEL)

run: unit run_only

run_only:
	$(GHDL) -r $(TOP_LEVEL) --ieee-asserts=disable $(STOP_TIME_ARG) $(RUN_ARGS) $(SIM_ARGS)

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.o $(TOP_LEVEL)

clean_all: clean clean_vpi

setup_vpi:
	$(CMAKE) $(VPI_DIR)/build

vpi:
	$(MAKE) -C $(VPI_DIR)/build vpi

clean_vpi:
	$(MAKE) -C $(VPI_DIR)/build clean
