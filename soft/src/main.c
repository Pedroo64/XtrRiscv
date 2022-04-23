#include <stdint.h>
#include "dev/io.h"
#include "dev/sio.h"
#include "riscv/csr.h"
#include "riscv/mtime.h"
#include <stdio.h>
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
    printf("Triggered ISR\n");
    printf("mcause = %08lX\n", csr_read(mcause));
    printf("mepc = %08lX\n", csr_read(mepc));
    switch ((csr_read(mcause) & 0xFF))
    {
    case MCAUSE_MACHINE_TIMER:
        printf("Timer interrupt\n");
        set_mtime_cmp(get_mtime() + MS_TO_TICKS(1000));
        break;
    case MCAUSE_MACHINE_EXTERNAL:
        printf("External interrupt\n");
    default:
        break;
    }
}

int test_program()
{
    char command[32];
    enable_machine_interrupts();
    //sio_puts(UART_NUM(0), "Hello, World\n\r");
    printf("Hello, World\n");
    //enable_timer_interrupts();
    while (1)
    {
        sio_gets(UART_NUM(0), command);
        if (!strcmp("enable interrupts", command))
            enable_external_interrupts();
        else if (!strcmp("disable interrupts", command))
            disable_external_interrupts();
        else if (!strcmp("ecall", command))
            ECALL();
        else if (!strcmp("mtime", command))
        {
            uint64_t dummy;
            dummy = get_mtime();
            printf("%s = %08lX%08lX\n", command, (uint32_t)(dummy >> 32), (uint32_t)(dummy));
            dummy = get_mtime_cmp();
            printf("%s_cmp = %08lX%08lX\n", command, (uint32_t)(dummy >> 32), (uint32_t)(dummy));
        }
        else if (!strcmp("dump csr", command))
        {
            //sio_printf(UART_NUM(0), "mie = %x\n", csr_read(mie));
            //sio_printf(UART_NUM(0), "mstatus = %x\n", csr_read(mstatus));
            printf("mie = %08lX\n", csr_read(mie));
            printf("mstatus = %08lX\n", csr_read(mstatus));
        }
        else if (!strcmp("enable timer interrupts", command))
            enable_timer_interrupts();
        else if (!strcmp("disable timer interrupts", command))
            disable_timer_interrupts();
        else
            printf("%s?\n", command);
    }
    return 0;
}
int test_program2()
{
    //sio_puts(UART_NUM(0), "Hello, World\n\r");
    ECALL();
    enable_machine_interrupts();
    enable_external_interrupts();
//    csr_read(mtime);
    while (1)
    {
        if (sio_available(UART_NUM(0)))
        {
            sio_putchar(UART_NUM(0), sio_getch(UART_NUM(0)));
        }
    }
}
int test_program3()
{
    enable_machine_interrupts();
    enable_timer_interrupts();
    while (1);
    return 0;
}
int main()
{
    return test_program();
}