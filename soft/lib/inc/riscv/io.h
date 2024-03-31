#ifndef __RISCV_IO_H__
#define __RISCV_IO_H__

/* Load / store macros */

#define	SB(data, offset, addr)                 \
    __asm __volatile (                         \
        "sb %0, %1(%2)"                        \
        :                                      \
        : "r" (data), "i" (offset), "r" (addr) \
    )

#define	SH(data, offset, addr)                 \
    __asm __volatile (                         \
        "sh %0, %1(%2)"                        \
        :                                      \
        : "r" (data), "i" (offset), "r" (addr) \
    )

#define	SW(data, offset, addr)                 \
    __asm __volatile (                         \
        "sw %0, %1(%2)"                        \
        :                                      \
        : "r" (data), "i" (offset), "r" (addr) \
    )

#define	LB(data, offset, addr)                 \
    __asm __volatile (                         \
        "lb %0, %1(%2)"                        \
        : "=r" (data)                          \
        : "i" (offset), "r" (addr)             \
    )

#define	LH(data, offset, addr)                 \
    __asm __volatile (                         \
        "lh %0, %1(%2)"                        \
        : "=r" (data)                          \
        : "i" (offset), "r" (addr)             \
    )

#define	LW(data, offset, addr)                 \
    __asm __volatile (                         \
        "lw %0, %1(%2)"                        \
        : "=r" (data)                          \
        : "i" (offset), "r" (addr)             \
    )

#endif // __RISCV_IO_H__
