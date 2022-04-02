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
void interrupt_handler(void)
{
    sio_puts(UART_NUM(0), "Triggered ISR\n\r");
}
int main()
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
        else
            sio_printf(UART_NUM(0), "%s?\n", command);
    }
    return 0;
}
