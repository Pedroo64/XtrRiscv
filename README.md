# XtrRiscv

This repository hosts a RISC-V CPU implementation in VHDL.
- 5 stage pipeline (fetch, decode, execute, memory, writeback)
- RV32I[M][C] compliant
- Friendly to all FPGA (no IP or primitive blocks are used)
- Full barrel shifter / Single shift
- Multiplication and division are iterative and takes 32 cycles to perform the operation
    - Optional DSP multiplication which takes 2 cycles
- External and Timer interrupts
- FreeRTOS support
- Optional debug module compliant to RISC-V Debug specification v1.0
