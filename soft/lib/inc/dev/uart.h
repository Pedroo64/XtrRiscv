#ifndef __UART_H__
#define __UART_H__

#include <sys/cdefs.h>

__BEGIN_DECLS

void uart_putc(void *base, char c);
void uart_puts(void *base, const char *s);

__END_DECLS

#endif // __UART_H__
