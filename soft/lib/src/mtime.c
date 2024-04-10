#include "dev/mtime.h"

inline uint64_t mtime(void *base) {
    return *(uint64_t *)(base);
}
inline uint64_t mtime_cmp_get(void *base) {
    return *(uint64_t *)(base);
}
void mtime_cmp_set(void *base, uint64_t value) {
    uint32_t *value_ptr = (uint32_t *)&value;
    uint32_t *base_ptr = (uint32_t *)base;
    base_ptr[1] = value_ptr[1];
    base_ptr[0] = value_ptr[0];
}
