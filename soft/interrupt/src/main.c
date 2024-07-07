#include "dev/io.h"
#include "dev/uart.h"
#include "riscv/csr.h"
#include <stdio.h>
#include <stdint.h>

#define ECALL() __asm __volatile("ecall")

extern void trap_entry();

void interrupt_handler() {
    uint32_t mcause, mepc;
    mcause = csr_read(mcause);
    mepc = csr_read(mepc);
    // printf("Trap! MEPC=%08lX", mepc);
    if (mcause & 0x80000000) {
        switch (mcause & ~0x80000000)
        {
        case MCAUSE_MACHINE_EXTERNAL:
            uart_puts(UART0_BASE, "MCAUSE_MACHINE_EXTERNAL\n\r");
            SW(0, 0, 0x80068000);
            break;
        case MCAUSE_MACHINE_TIMER:
            uart_puts(UART0_BASE, "MCAUSE_MACHINE_TIMER\n\r");
            break;
        default:
            uart_puts(UART0_BASE, "Unknown external cause!\n\r");
            break;
        }
    } else {
        switch (mcause & ~0x80000000)
        {
        case MCAUSE_MACHILE_ECALL:
            uart_puts(UART0_BASE, "MCAUSE_ECALL\n\r");
            csr_write(mepc, mepc + 4);
            break;
        case MCAUSE_EBREAK:
            uart_puts(UART0_BASE, "MCAUSE_EBREAK\n\r");
            csr_write(mepc, mepc + 4);
            break;
        default:
            uart_puts(UART0_BASE, "Unknown cause!\n\r");
        }
    }
}

int main(int argc, char const *argv[]) {
    csr_read_set(mtvec,   &trap_entry);
    csr_read_set(mstatus, MSTATUS_MIE);
    csr_read_set(mie,     MIE_MEIE);

    SW(1, 0, 0x80060000);

    ECALL();

    char str[] = "Hello, World\n\r";
    for (char *c = str; *c != 0; c++) {
        uart_putc(UART0_BASE, *c);
    }
    while (1);
    return 0;
}
