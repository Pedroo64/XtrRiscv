.global crt_start

.section	.start_jump,"ax",@progbits
crt_start:
    //long jump to allow crt_init to be anywhere
    //do it always in 12 bytes
    lui x2,       %hi(crt_init)
    addi x2, x2,  %lo(crt_init)
    jalr x1,x2
    nop

crt_init:
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    la sp, _stack_start

    call main

loop:
#ifdef SIM_BUILD
    li t0, 0xCAFECAFE
    li t1, 0x80020000
    sw t0, 0(t1)
#endif
    j loop
