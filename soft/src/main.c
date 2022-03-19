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
int sio_print_number(unsigned long n, uint8_t base_print)
{
    char buf[8 * sizeof(long) + 1]; // Assumes 8-bit chars plus zero byte.
    char* str = &buf[sizeof(buf) - 1];

    *str = '\0';

    // prevent crash if called with base_print == 1
    if (base_print < 2) base_print = 10;

    do {
        char c = n % base_print;
        n /= base_print;

        *--str = c < 10 ? c + '0' : c + 'A' - 10;
    } while (n);

    return sio_puts(str);
}
int sio_available()
{
    int ret;
    LB(ret, 1, SIO_BASE);
    return ret & (SIO_RX_AVAILABLE >> 8) ? 1 : 0;
}
int sio_print_float(float number, int digits)
{
    int n = 0;
    uint32_t *number32 = (uint32_t *)&number;
    if (((*number32) & 0x7F800000) == 0x7F800000)
    {
        if (((*number32) & 0x007FFFFF) != 0)
            sio_puts("nan\n");
        else if ((*number32) & 0x80000000)
            sio_puts("-inf\n");
        else
            sio_puts("inf\n");
    }
    // Handle negative numbers
    if (number < 0.0f)
    {
        n += sio_putchar('-');
        number = -number;
    }

    // Round correctly so that print(1.999, 2) prints as "2.00"
    double rounding = 0.5;
    for (int i = 0; i < digits; ++i)
        rounding /= 10.0;

    number += rounding;

    // Extract the integer part of the number and print it
    unsigned long int_part = (unsigned long)number;
    float remainder = number - (float)int_part;
    n += sio_print_number(int_part, 10);

    // Print the decimal point, but only if there are digits beyond
    if (digits > 0) 
        n += sio_putchar('.');

    // Extract digits from the remainder one at a time
    while (digits-- > 0)
    {
        remainder *= 10.0f;
        unsigned int toPrint = (unsigned int)(remainder);
        n += sio_print_number(toPrint, 10);
        remainder -= toPrint;
    }
    return n;
}
#define print_value(value_name, value, base) sio_puts(value_name); sio_print_number(value, base); sio_puts("\n\r")
#define print_float_value(value_name, value, digits) sio_puts(value_name); sio_print_float(value, digits); sio_puts("\n\r")
#include "riscv/csr.h"
int main()
{
    int csr;
    int value = 10;
    float fvalue = 10.0;
    double dvalue = 10.0;
    uint32_t *ptr = (uint32_t *)0;
    csr_write(0, 0xBBBBBBBB);
    csr_write(0, 0xAAAAAAAA);
    //csr_read_set(0, 0);
    csr = csr_read(0);
    print_value("csr = ", csr, 16);
    csr = csr >> 16; 
    print_value("csr = ", csr, 16);
    print_value("value = ", value, 10);
    value = value * 10;
    print_value("value = ", value, 10);
    value = value / 5;
    print_value("value = ", value, 10);
    ptr = (uint32_t *)(&fvalue);
    print_float_value("fvalue = ", fvalue, 10); print_value("*fvalue32 = ", *ptr, 16);
    fvalue = fvalue * 10.0f;
    print_float_value("fvalue = ", fvalue, 10); print_value("*fvalue32 = ", *ptr, 16);
    fvalue = fvalue / 5.0f;
    print_float_value("fvalue = ", fvalue, 10); print_value("*fvalue32 = ", *ptr, 16);
    
    ptr = (uint32_t *)(&dvalue);
    print_value("*fvalue64[63:32] = ", *(ptr + 1), 16); print_value("*fvalue64[31:0] = ", *ptr, 16); 
    dvalue = dvalue * 10.0;
    print_value("*fvalue64[63:32] = ", *(ptr + 1), 16); print_value("*fvalue64[31:0] = ", *ptr, 16); 
    dvalue = dvalue / 5.0;
    print_value("*fvalue64[63:32] = ", *(ptr + 1), 16); print_value("*fvalue64[31:0] = ", *ptr, 16); 
    
    while (1)
    {
        if (sio_available())
        {
            sio_putchar(sio_getch());
        }
    }
    return 0;
}
