#ifndef __MTIME_H__
#define __MTIME_H__

#include <stdint.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

uint64_t mtime(void *base);
uint64_t mtime_cmp_get(void *base);
void mtime_cmp_set(void *base, uint64_t value);

__END_DECLS

#endif // __MTIME_H__
