#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H


//#define RVTEST_IO_QUIET
#define SIM_STDOUT_BASE 0x80000000
#define SIM_FILE_BASE   0x80010000
#define SIM_STOP_SIM    0x80020000

#define RVMODEL_DATA_SECTION                                        \
    .pushsection .tohost,"aw",@progbits;                            \
    .align 8; .global tohost; tohost: .dword 0;                     \
    .align 8; .global fromhost; fromhost: .dword 0;                 \
    .popsection;                                                    \
    .align 8; .global begin_regstate; begin_regstate:               \
    .word 128;                                                      \
    .align 8; .global end_regstate; end_regstate:                   \
    .word 4;

//TODO: declare the start of your signature region here. Nothing else to be used here.
// The .align 4 ensures that the signature ends at a 16-byte boundary
#define RVMODEL_DATA_BEGIN                                          \
    .align 4; .global begin_signature; begin_signature:

//TODO: declare the end of the signature region here. Add other target specific contents here.
#define RVMODEL_DATA_END                                            \
    .align 4; .global end_signature; end_signature:                 \
    RVMODEL_DATA_SECTION                                                        

//TODO: Add code here to run after all tests have been run
// The .align 4 ensures that the signature begins at a 16-byte boundary
#define RVMODEL_HALT                                                \
    la a2, begin_signature;                                         \
    la a3, end_signature;                                           \
loop:                                                               \
    bge a2, a3, done;                                               \
    lw a0, 0(a2);                                                   \
    li a1, SIM_FILE_BASE;                                           \
    jal FN_WriteNmbr;                                               \
    LOCAL_IO_PUTS("\n", SIM_FILE_BASE);                        \
    addi a2, a2, 4;                                                 \
    j loop;                                                         \
done:                                                               \
    la t1, SIM_STOP_SIM;                                            \
    li t0, 0xCAFECAFE;                                              \
    sw t0, 0(t1);                                                   \
    self_loop:  j self_loop;                                        

//RVMODEL_BOOT
#define RVMODEL_BOOT                \
  .section .test.init;              \
  .align 4;                         \
  .globl _start;                    \
_start:                             \

//RVTEST_IO_INIT

// _SP = (volatile register)
//TODO: Macro to output a string to IO
#define LOCAL_IO_PUTS(_STR, _BASE)                                      \
    .section .data.string;                                              \
20001:                                                                  \
    .string _STR;                                                       \
    .section .text.init;                                                \
    la a0, 20001b;                                                      \
    la a1, _BASE;                                                       \
    jal FN_WriteStr;

#define LOCAL_IO_WRITE_STR(_STR) RVMODEL_IO_WRITE_STR(x31, _STR)
#define RVMODEL_IO_WRITE_STR(_SP, _STR)                                 \
    .section .data.string;                                              \
20001:                                                                  \
    .string _STR;                                                       \
    .section .text.init;                                                \
    la a0, 20001b;                                                      \
    la a1, SIM_STDOUT_BASE;                                             \
    jal FN_WriteStr;

#define RSIZE 4
// _SP = (volatile register)
#define LOCAL_IO_PUSH(_SP)                                              \
    la      _SP,  begin_regstate;                                       \
    sw      ra,   (1*RSIZE)(_SP);                                       \
    sw      t0,   (2*RSIZE)(_SP);                                       \
    sw      t1,   (3*RSIZE)(_SP);                                       \
    sw      t2,   (4*RSIZE)(_SP);                                       \
    sw      t3,   (5*RSIZE)(_SP);                                       \
    sw      t4,   (6*RSIZE)(_SP);                                       \
    sw      s0,   (7*RSIZE)(_SP);                                       \
    sw      a0,   (8*RSIZE)(_SP);

// _SP = (volatile register)
#define LOCAL_IO_POP(_SP)                                               \
    la      _SP,   begin_regstate;                                      \
    lw      ra,   (1*RSIZE)(_SP);                                       \
    lw      t0,   (2*RSIZE)(_SP);                                       \
    lw      t1,   (3*RSIZE)(_SP);                                       \
    lw      t2,   (4*RSIZE)(_SP);                                       \
    lw      t3,   (5*RSIZE)(_SP);                                       \
    lw      t4,   (6*RSIZE)(_SP);                                       \
    lw      s0,   (7*RSIZE)(_SP);                                       \
    lw      a0,   (8*RSIZE)(_SP);

//RVMODEL_IO_ASSERT_GPR_EQ
// Test to see if a specific test has passed or not.  Can assert or not.
#ifdef RVTEST_IO_QUIET
#define RVMODEL_IO_ASSERT_GPR_EQ(_SP, _R, _I)
#else
#define RVMODEL_IO_ASSERT_GPR_EQ(_SP, _R, _I)                           \
    LOCAL_IO_PUSH(_SP)                                                  \
    mv          s0, _R;                                                 \
    li          t5, _I;                                                 \
    beq         s0, t5, 20003f;                                         \
    LOCAL_IO_WRITE_STR("Test Failed ");                                 \
    LOCAL_IO_WRITE_STR(": ");                                           \
    LOCAL_IO_WRITE_STR(# _R);                                           \
    LOCAL_IO_WRITE_STR("( ");                                           \
    mv      a0, s0;                                                     \
    jal FN_WriteNmbr;                                                   \
    LOCAL_IO_WRITE_STR(" ) != ");                                       \
    mv      a0, t5;                                                     \
    jal FN_WriteNmbr;                                                   \
    LOCAL_IO_WRITE_STR("\n");                                           \
    j 20003f;                                                           \
20002:                                                                  \
    LOCAL_IO_WRITE_STR("Test Passed\n")                                 \
20003:                                                                  \
    LOCAL_IO_POP(_SP)
#endif


.section .text
// FN_WriteStr: Add code here to write a string to IO
// FN_WriteNmbr: Add code here to write a number (32/64bits) to IO

#define LOCAL_IO_PUTC(_R, _B)           \
    mv          t3, _B;		            \
    sw          _R, (0)(t3);			\

FN_WriteStr:
    mv          t0, a0;
10000:
    lbu         a0, (t0);
    addi        t0, t0, 1;
    beq         a0, zero, 10000f;
    LOCAL_IO_PUTC(a0, a1);
    j           10000b;
10000:
    ret;

FN_WriteNmbr:
        mv          t0, a0
        li          t1, 8
10000:  slli        t2, t2, 4
        andi        a0, t0, 0xf
        srli        t0, t0, 4
        or          t2, t2, a0
        addi        t1, t1, -1
        bnez        t1, 10000b
        li          t1, 8
        li          t0, 10
10001:  andi        a0, t2, 0xf
        blt         a0, t0, 10002f
        addi        a0, a0, 'a'-10
        j           10003f
10002:  addi        a0, a0, '0'
10003:  LOCAL_IO_PUTC(a0, a1)
        srli        t2, t2, 4
        addi        t1, t1, -1
        bnez        t1, 10001b
        ret

//RVTEST_IO_ASSERT_SFPR_EQ
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
//RVTEST_IO_ASSERT_DFPR_EQ
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

// TODO: specify the routine for setting machine software interrupt
#define RVMODEL_SET_MSW_INT

// TODO: specify the routine for clearing machine software interrupt
#define RVMODEL_CLEAR_MSW_INT

// TODO: specify the routine for clearing machine timer interrupt
#define RVMODEL_CLEAR_MTIMER_INT

// TODO: specify the routine for clearing machine external interrupt
#define RVMODEL_CLEAR_MEXT_INT

#define RVMODEL_CLR_MSW_INT
#define RVMODEL_CLR_MTIMER_INT
#define RVMODEL_CLR_MEXT_INT
#define RVMODEL_SET_SSW_INT
#define RVMODEL_CLR_SSW_INT
#define RVMODEL_CLR_STIMER_INT
#define RVMODEL_CLR_SEXT_INT
#define RVMODEL_SET_VSW_INT
#define RVMODEL_CLR_VSW_INT
#define RVMODEL_CLR_VTIMER_INT
#define RVMODEL_CLR_VEXT_INT

#endif // _COMPLIANCE_MODEL_H

