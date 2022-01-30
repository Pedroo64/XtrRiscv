#include <stdint.h>
#include "io.h"

#define SIO_BASE 0x80000000
#define SIO_TX_RDY 0x100
#define SIO_RX_AVAILABLE 0x400

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
int sio_getch()
{
    int ret;
    LW(ret, 0, SIO_BASE);
    return ret & 0xFF;
}
int sio_available()
{
    int ret;
    LB(ret, 1, SIO_BASE);
    return ret & (SIO_RX_AVAILABLE >> 8) ? 1 : 0;
}

int main()
{
    sio_puts("Hello, World\n\r");
    //for (int i = 0; i < 32; i++)
    //    sio_putchar(0x1 << i);
    while (1)
    {
        if (sio_available())
        {
            sio_putchar(sio_getch());
        }
    }
    return 0;
}
