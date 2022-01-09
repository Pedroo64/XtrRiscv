#include <stdint.h>
#include "io.h"

#define SIO_BASE 0x80000000
#define SIO_TX_RDY 0x100

int sio_putchar(int c)
{
    int rdy;
    do
    {
        LW(rdy, 0, SIO_BASE);    
    } 
    while (!(rdy & SIO_TX_RDY));
    SB(c, 0, SIO_BASE);
    return 0;
}

int sio_puts(const char *str)
{
    while (*str != '\0')
    {
        sio_putchar(*str);
        str++;
    }
    return 0;
}

int main()
{
    sio_puts("Hello, World\n\r");
    while (1);
    return 0;
}
