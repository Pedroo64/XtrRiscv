MKFILE_PATH =  $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR  =  $(dir $(MKFILE_PATH))

VSIM        ?= vsim
VSIM_FLAGS  ?=
SRCS_PATH    = $(MKFILE_DIR)/../..

INIT_FILE	?= "none"
OUTPUT_FILE	?= "none"
EXECUTE_BYPASS ?= FALSE
MEMORY_BYPASS ?= FALSE
WRITEBACK_BYPASS ?= FALSE
FULL_BARREL_SHIFTER ?= FALSE
ZICSR ?= TRUE

all: compile

create_project:
	@rm -rf work
	@mkdir work
	$(VSIM) -c $(VSIM_FLAGS) -do "project new work proj;  exit -f"

add_sources: create_project
	$(VSIM) -c $(VSIM_FLAGS) -nolog -do "project open work/proj.mpf; \
		project addfile $(SRCS_PATH)/cpu/comparator.vhd; \
		project addfile $(SRCS_PATH)/cpu/alu.vhd; \
		project addfile $(SRCS_PATH)/cpu/rv32i_pkg.vhd; \
		project addfile $(SRCS_PATH)/cpu/shifter.vhd; \
		project addfile $(SRCS_PATH)/cpu/csr_def.vhd; \
		project addfile $(SRCS_PATH)/cpu/instruction_fetch.vhd; \
		project addfile $(SRCS_PATH)/cpu/instruction_decode.vhd; \
		project addfile $(SRCS_PATH)/cpu/execute.vhd; \
		project addfile $(SRCS_PATH)/cpu/memory.vhd; \
		project addfile $(SRCS_PATH)/cpu/writeback.vhd; \
		project addfile $(SRCS_PATH)/cpu/csr.vhd; \
		project addfile $(SRCS_PATH)/cpu/regfile.vhd; \
		project addfile $(SRCS_PATH)/cpu/control_unit.vhd; \
		project addfile $(SRCS_PATH)/cpu/interrupt_handler.vhd; \
		project addfile $(SRCS_PATH)/cpu/branch_unit.vhd; \
		project addfile $(SRCS_PATH)/cpu/cpu.vhd; \
		project addfile $(SRCS_PATH)/utils/utils.vhd; \
		project addfile $(SRCS_PATH)/utils/xtr_def.vhd; \
		project addfile $(SRCS_PATH)/utils/xtr_abr.vhd; \
		project addfile $(SRCS_PATH)/utils/data_handshake.vhd; \
		project addfile $(SRCS_PATH)/cpu/xtr_cpu.vhd; \
		project addfile $(SRCS_PATH)/soc/ram/bram.vhd; \
		project addfile $(SRCS_PATH)/soc/ram/xtr_ram.vhd; \
		project addfile $(SRCS_PATH)/testbenches/src/sim_stdout.vhd; \
		project addfile $(SRCS_PATH)/testbenches/src/sim_file.vhd; \
		project addfile $(SRCS_PATH)/testbenches/src/sim_soc.vhd; \
		project addfile $(SRCS_PATH)/testbenches/tb_xtr_soc.vhd; \
		exit -f" 

compile: add_sources
	$(VSIM) -c $(VSIM_FLAGS) -do "project open work/proj.mpf; project compileall; exit -f"

open_project:
	$(VSIM) $(VSIM_FLAGS) -do "project open work/proj.mpf;"

start_sim:
	$(VSIM) $(VSIM_FLAGS) -do "project open work/proj.mpf; vsim -voptargs=+acc work.tb_xtr_soc -gG_INIT_FILE="$(MKFILE_DIR)/$(INIT_FILE)" -gG_OUTPUT_FILE="$(OUTPUT_FILE)" -gG_EXECUTE_BYPASS=$(WRITEBACK_BYPASS) -gG_MEMORY_BYPASS=$(MEMORY_BYPASS) -gG_WRITEBACK_BYPASS=$(WRITEBACK_BYPASS) -gG_FULL_BARREL_SHIFTER=$(FULL_BARREL_SHIFTER) \
		-gG_ZICSR=$(ZICSR); \
		add wave -divider "fetch" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_fetch/*; \
		add wave -divider "decode" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_decode/*; \
		add wave -divider "regfile" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_regfile/*; \
		add wave -divider "execute" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_execute/*; \
		add wave -divider "memory" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_memory/*; \
		add wave -divider "writeback" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_writeback/*; \
		add wave -divider "ctl" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_control_unit/*; \
		add wave -divider "branch" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_branch_unit/*; \
		add wave -divider "csr" -position insertpoint sim:/tb_xtr_soc/u_xtr_soc/u_xtr_cpu/u_cpu/u_csr/*; \
		set NumericStdNoWarnings 1; config wave -signalnamewidth 1"

clean:
	@rm -r work