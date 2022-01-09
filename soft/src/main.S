.global crtStart
.global main
.global interrupt_handler
.global trap_entry
#ifndef TRAP_ENTRY
#define TRAP_ENTRY trap_entry
#endif

.section	.start_jump,"ax",@progbits
crtStart:
  //long jump to allow crtInit to be anywhere
  //do it always in 12 bytes
  lui x2,       %hi(crtInit)
  addi x2, x2,  %lo(crtInit)
  jalr x1,x2
  nop

.section .text
crtInit:
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, _stack_start

  call main
infinitLoop:
  j infinitLoop