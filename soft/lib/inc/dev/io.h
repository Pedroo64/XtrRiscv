#ifndef __IO_H__
#define __IO_H__

#include "riscv/io.h"

#define MTIME_BASE (void *)(0xFFFFF400)

#ifdef SIM_BUILD
#define UART0_BASE (void *)0x80000000
#else
#define UART0_BASE (void *)0xFFFFFB00
#endif

#endif
