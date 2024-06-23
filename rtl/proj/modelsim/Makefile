ROOT_DIR = $(shell git rev-parse --show-toplevel)

#
# DUT Arguments
#

INIT_FILE	            ?= none
OUTPUT_FILE	            ?= none
EXECUTE_BYPASS          ?= TRUE
MEMORY_BYPASS           ?= TRUE
WRITEBACK_BYPASS        ?= TRUE
REGFILE_BYPASS          ?= TRUE
FULL_BARREL_SHIFTER     ?= TRUE
SHIFTER_EARLY_INJECTION ?= TRUE
EXTENSION_ZICSR         ?= TRUE
EXTENSION_M             ?= TRUE
EXTENSION_C             ?= TRUE
DEBUG_MODULE            ?= TRUE

#
# Simulator Arguments
#

TOP_LEVEL   ?= tb_xtr_soc
WAVE        ?= $(MKFILE_DIR)/work/wave.wlf

COVERAGE    ?= 0
SPEED       ?= 0

STOP_TIME   ?=
GUI          = 0

VSIM        ?= vsim
VCOM        ?= vcom
VSIM_FLAGS  ?=

#
# Design sources
#

RTL_DIR       = $(ROOT_DIR)/rtl
FLI_DIR       = $(ROOT_DIR)/rtl/testbenches/src/fli/build

VHDL_SOURCES += $(RTL_DIR)/utils/vhdl_utils.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/rv32i_pkg.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/csr_def.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/cpu_checker.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/comparator.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/alu.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/c_extension/decompressor.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/m_extension/mul.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/m_extension/div.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/m_extension/muldiv.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/shifter.vhd
VHDL_SOURCES += $(RTL_DIR)/cpu/instruction_fetch.vhd
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
VHDL_SOURCES += $(RTL_DIR)/testbenches/src/fli/rtl/jtag_vpi.vhd
VHDL_SOURCES += $(RTL_DIR)/testbenches/tb_xtr_soc.vhd

#
# Internal
#

SPEED_ARG    = -voptargs=+acc
BATCH        =
COVERAGE_ARG =
WAVE_ARG     =
LOG_WAVE     =

ifeq ($(GUI), 0)
    BATCH = -c
endif

ifeq ($(SPEED), 1)
	SPEED_ARG = -vopt
endif

ifeq ($(COVERAGE), 1)
	COVERAGE_ARG = -coverage
endif

ifneq ($(WAVE),)
	ifeq ($(SPEED), 0)
		WAVE_ARG = -wlf $(WAVE)
		LOG_WAVE = log * -r
	endif
endif

ifneq ($(STOP_TIME),)
    RUN_ARG = run $(STOP_TIME)
else
    RUN_ARG = run -all
endif

SIM_ARGS=\
	-gG_INIT_FILE="$(INIT_FILE)" -gG_OUTPUT_FILE="$(OUTPUT_FILE)" \
	-gG_EXECUTE_BYPASS=$(WRITEBACK_BYPASS) -gG_MEMORY_BYPASS=$(MEMORY_BYPASS) -gG_WRITEBACK_BYPASS=$(WRITEBACK_BYPASS) -gG_REGFILE_BYPASS=$(REGFILE_BYPASS) \
	-gG_FULL_BARREL_SHIFTER=$(FULL_BARREL_SHIFTER) -gG_SHIFTER_EARLY_INJECTION=$(SHIFTER_EARLY_INJECTION) \
	-gG_EXTENSION_ZICSR=$(EXTENSION_ZICSR) -gG_EXTENSION_M=$(EXTENSION_M) -gG_EXTENSION_C=$(EXTENSION_C) \
	-gG_DEBUG_MODULE=$(DEBUG_MODULE) \
	-g/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/G_VERIFICATION=TRUE; \
	set NumericStdNoWarnings 1

compile:
	$(VCOM) -autoorder -check_synthesis $(VHDL_SOURCES)

run:
	$(VSIM) $(BATCH) -do "vsim $(SPEED_ARG) work.$(TOP_LEVEL) $(WAVE_ARG) $(SIM_ARGS); $(LOG_WAVE); $(RUN_ARG); exit;"

restore:
	$(VSIM) -view $(WAVE)

clean:
	rm -rf work
