# XtrRiscv

This repository hosts a RISC-V CPU implementation in VHDL. This has the following specs :
- Runs RV32I instruction set
- Instructions run over a 5 stage pseudo classic pipeline (fetch, decode, execute, memory, writeback)
- Friendly to all FPGA (no IP or primitive blocks are used)
- Full barrel shifter
- External and Timer interrupts
- FreeRTOS support

 CPU runs RV32I instructions over a 5 stage pipeline (fetch, decode, execute, memory, writeback).

This CPU implementation has every stage explicitly implemented so that can be used to understand how a CPU pipeline works or to easily add new features to a specific stage of the pipeline. For example to add M extension of RISC-V only the decode and execute stage need to be modified.

Independently attached to some peripherals for testing, the design can run over 100 MHz on the [Digilent Arty S7-50](https://digilent.com/shop/arty-s7-spartan-7-fpga-development-board) board and on [Lattice CrossLink-NX evaluation board](https://www.latticesemi.com/en/Products/DevelopmentBoardsAndKits/CrossLink-NXEvaluationBoard).

Here is a diagram how the CPU pipeline is disposed : 

![](docs/img/xtr_riscv_pipeline.svg)

Instruction bus and data bus are inspired from [VexRiscv](https://github.com/SpinalHDL/VexRiscv). Here is a waveform of a read, write and write with a wait state and read with a wait state : 

![waveform](docs/img/bus_waveform.svg#dark)