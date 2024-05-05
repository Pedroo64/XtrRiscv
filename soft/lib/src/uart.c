#include "dev/io.h"
#include "dev/uart.h"

#define UART_TX_BUSY 0x4
#define UART_RX_FULL 0x1

void uart_putc(void *base, char c) {
    char s;
    do {
        LB(s, 1, base);
    } while (s & UART_TX_BUSY);
    SB(c, 0, base);
}

void uart_puts(void *base, const char *s) {
    char c;
    while (*s) {
        c = *s;
        uart_putc(base, c);
        s++;
    }
}
