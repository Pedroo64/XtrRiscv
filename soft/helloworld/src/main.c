#include "dev/io.h"
#include "dev/uart.h"

int main(int argc, char const *argv[]) {
    char str[] = "Hello, World\n\r";
    for (char *c = str; *c != 0; c++) {
        uart_putc(UART0_BASE, *c);
    }
    return 0;
}
