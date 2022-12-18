VSIM        ?= vsim
VSIM_FLAGS  ?=
SRCS_PATH=../..

all: compile

create_project:
	$(VSIM) -c $(VSIM_FLAGS) -do "project new . proj;  exit -f"

add_sources: create_project
	$(VSIM) -c $(VSIM_FLAGS) -nolog -do "project open proj.mpf; \
		project addfile $(SRCS_PATH)/cpu/alu_pkg.vhd; \
		project addfile $(SRCS_PATH)/cpu/alu.vhd; \
		project addfile $(SRCS_PATH)/cpu/rv32i_pkg.vhd; \
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
		project addfile $(SRCS_PATH)/cpu/cpu.vhd; \
		project addfile $(SRCS_PATH)/utils/utils.vhd; \
		project addfile $(SRCS_PATH)/utils/xtr_def.vhd; \
		project addfile $(SRCS_PATH)/utils/xtr_abr.vhd; \
		project addfile $(SRCS_PATH)/cpu/xtr_cpu.vhd; \
		project addfile $(SRCS_PATH)/soc/ram/bram.vhd; \
		project addfile $(SRCS_PATH)/soc/ram/xtr_ram.vhd; \
		project addfile $(SRCS_PATH)/testbenches/src/sim_stdout.vhd; \
		project addfile $(SRCS_PATH)/testbenches/src/sim_file.vhd; \
		project addfile $(SRCS_PATH)/testbenches/src/sim_soc.vhd; \
		project addfile $(SRCS_PATH)/testbenches/tb_xtr_soc.vhd; \
		exit -f" 

compile: add_sources
	$(VSIM) -c $(VSIM_FLAGS) -do "project open proj.mpf; project compileall; exit -f"

clean:
	rm -r work
	rm *.ini
	rm *.mti
	rm *.mpf