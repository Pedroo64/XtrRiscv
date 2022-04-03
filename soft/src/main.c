#include <stdint.h>
#include "dev/io.h"
#include "dev/sio.h"
#include "riscv/csr.h"
#include <string.h>
inline void enable_machine_interrupts()
{
    csr_read_set(mstatus, MSTATUS_MIE);
}
inline void disable_machine_interrupts()
{
    csr_read_clear(mstatus, MSTATUS_MIE);
}
inline void enable_external_interrupts()
{
    csr_read_set(mie, MIE_MEIE);
}
inline void disable_external_interrupts()
{
    csr_read_clear(mie, MIE_MEIE);
}
inline void enable_timer_interrupts()
{
    csr_read_set(mie, MIE_MTIE);
}
inline void disable_timer_interrupts()
{
    csr_read_clear(mie, MIE_MTIE);
}
#define ECALL() __asm__ __volatile__ ("ecall")
void interrupt_handler(void)
{
    sio_puts(UART_NUM(0), "Triggered ISR\n\r");
    sio_printf(UART_NUM(0), "mcause = %x\n", csr_read(mcause));
    sio_printf(UART_NUM(0), "mepc = %x\n", csr_read(mepc));
}

int test_program()
{
    char command[32];
    enable_machine_interrupts();
    sio_puts(UART_NUM(0), "Hello, World\n\r");
    while (1)
    {
        sio_gets(UART_NUM(0), command);
        if (!strcmp("enable interrupts", command))
            enable_external_interrupts();
        else if (!strcmp("disable interrupts", command))
            disable_external_interrupts();
        else if (!strcmp("ecall", command))
            ECALL();
        else
            sio_printf(UART_NUM(0), "%s?\n", command);
    }
    return 0;
}
int test_program2()
{
    sio_puts(UART_NUM(0), "Hello, World\n\r");
    ECALL();
    enable_machine_interrupts();
    enable_external_interrupts();
    while (1)
    {
        if (sio_available(UART_NUM(0)))
        {
            sio_putchar(UART_NUM(0), sio_getch(UART_NUM(0)));
        }
    }
}
int main()
{
    return test_program();
}