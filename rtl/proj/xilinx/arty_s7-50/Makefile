
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(notdir $(patsubst %/,%,$(dir $(MKFILE_PATH))))

VIVADO       ?= vivado
VIVADO_FLAGS  = -mode batch -nolog -nojournal -tempDir $(BUILD_DIR)
JOBS      ?= 4
PROJECT   ?= xtrriscv
BUILD_DIR ?= build
DESIGN     = top
DEVICE     = xc7s50csga324-1
XCF        = ./constraints/arty.xdc
RTL_DIR    = ./../../..
SRC        = $(RTL_DIR)/utils/vhdl_utils.vhd
SRC       += $(RTL_DIR)/cpu/rv32i_pkg.vhd
SRC       += $(RTL_DIR)/cpu/csr_def.vhd
SRC       += $(RTL_DIR)/cpu/cpu_checker.vhd
SRC       += $(RTL_DIR)/cpu/utils/cpu_fifo.vhd
SRC       += $(RTL_DIR)/cpu/comparator.vhd
SRC       += $(RTL_DIR)/cpu/c_extension/decompressor.vhd
SRC       += $(RTL_DIR)/cpu/c_extension/instruction_aligner.vhd
SRC       += $(RTL_DIR)/cpu/m_extension/mul.vhd
SRC       += $(RTL_DIR)/cpu/m_extension/div.vhd
SRC       += $(RTL_DIR)/cpu/m_extension/muldiv.vhd
SRC       += $(RTL_DIR)/cpu/shifter.vhd
SRC       += $(RTL_DIR)/cpu/regfile.vhd
SRC       += $(RTL_DIR)/cpu/lsu.vhd
SRC       += $(RTL_DIR)/cpu/debug/dtm_pkg.vhd
SRC       += $(RTL_DIR)/cpu/debug/dtm_jtag.vhd
SRC       += $(RTL_DIR)/cpu/debug/debug_module_pkg.vhd
SRC       += $(RTL_DIR)/cpu/debug/debug_module.vhd
SRC       += $(RTL_DIR)/cpu/cpu.vhd
SRC       += $(RTL_DIR)/utils/utils.vhd
SRC       += $(RTL_DIR)/utils/xtr_def.vhd
SRC       += $(RTL_DIR)/utils/xtr_abr.vhd
SRC       += $(RTL_DIR)/cpu/xtr_cpu.vhd
SRC       += $(RTL_DIR)/soc/ram/bram.vhd
SRC       += $(RTL_DIR)/soc/ram/xtr_ram.vhd
SRC       += $(RTL_DIR)/soc/uart/uart_rx.vhd
SRC       += $(RTL_DIR)/soc/uart/uart_tx.vhd
SRC       += $(RTL_DIR)/soc/uart/xtr_uart.vhd
SRC       += $(RTL_DIR)/soc/timer/xtr_mtime.vhd
SRC       += $(RTL_DIR)/soc/boottrap/boot_trap.vhd
SRC       += $(RTL_DIR)/soc/boottrap/xtr_boot_trap.vhd
SRC       += $(RTL_DIR)/soc/xtr_peripherials.vhd
SRC       += $(RTL_DIR)/soc/xtr_soc.vhd
SRC       += $(RTL_DIR)/proj/xilinx/arty_s7-50/src/top.vhd

translate: $(BUILD_DIR)/$(DESIGN)/opt.dcp
place_and_route: $(BUILD_DIR)/$(DESIGN)/route.dcp
bitstream: $(BUILD_DIR)/$(DESIGN)/bitstream.bit

create_project:
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs project_create $(BUILD_DIR) $(PROJECT) $(DEVICE) $(DESIGN) $(XCF) $(SRC)

open_project:
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs project_open $(BUILD_DIR) $(PROJECT) $(DESIGN)

get_device_list:
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs get_device_list

program_device: bitstream
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs program_device $(BOARD_DEVICE) $(BUILD_DIR)/$(DESIGN)/bitstream.bit

$(BUILD_DIR)/$(DESIGN)/syn.dcp: $(SRC) $(XCF) ./vivado.tcl
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs syn $(BUILD_DIR) $(JOBS) $(DEVICE) $(DESIGN) $(XCF) $(SRC)

$(BUILD_DIR)/$(DESIGN)/opt.dcp: $(BUILD_DIR)/$(DESIGN)/syn.dcp
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs opt $(BUILD_DIR) $(JOBS) $(DESIGN)

$(BUILD_DIR)/$(DESIGN)/route.dcp: $(BUILD_DIR)/$(DESIGN)/opt.dcp
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs place_and_route $(BUILD_DIR) $(JOBS) $(DESIGN)

$(BUILD_DIR)/$(DESIGN)/bitstream.bit: $(BUILD_DIR)/$(DESIGN)/route.dcp
	$(VIVADO) $(VIVADO_FLAGS) -source ./vivado.tcl -tclargs bitstream $(BUILD_DIR) $(JOBS) $(DESIGN)

clean:
	rm -rf $(BUILD_DIR)
