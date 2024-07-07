.global interrupt_handler
#define store_x sw
#define load_x lw
#define portWORD_SIZE 4
#define portCONTEXT_SIZE ( 30 * portWORD_SIZE )

.section .text

.global  trap_entry
.align 5
trap_entry:
    addi sp, sp, -portCONTEXT_SIZE
    store_x x1, 1 * portWORD_SIZE( sp )
    store_x x5, 2 * portWORD_SIZE( sp )
    store_x x6, 3 * portWORD_SIZE( sp )
    store_x x7, 4 * portWORD_SIZE( sp )
    store_x x8, 5 * portWORD_SIZE( sp )
    store_x x9, 6 * portWORD_SIZE( sp )
    store_x x10, 7 * portWORD_SIZE( sp )
    store_x x11, 8 * portWORD_SIZE( sp )
    store_x x12, 9 * portWORD_SIZE( sp )
    store_x x13, 10 * portWORD_SIZE( sp )
    store_x x14, 11 * portWORD_SIZE( sp )
    store_x x15, 12 * portWORD_SIZE( sp )
    store_x x16, 13 * portWORD_SIZE( sp )
    store_x x17, 14 * portWORD_SIZE( sp )
    store_x x18, 15 * portWORD_SIZE( sp )
    store_x x19, 16 * portWORD_SIZE( sp )
    store_x x20, 17 * portWORD_SIZE( sp )
    store_x x21, 18 * portWORD_SIZE( sp )
    store_x x22, 19 * portWORD_SIZE( sp )
    store_x x23, 20 * portWORD_SIZE( sp )
    store_x x24, 21 * portWORD_SIZE( sp )
    store_x x25, 22 * portWORD_SIZE( sp )
    store_x x26, 23 * portWORD_SIZE( sp )
    store_x x27, 24 * portWORD_SIZE( sp )
    store_x x28, 25 * portWORD_SIZE( sp )
    store_x x29, 26 * portWORD_SIZE( sp )
    store_x x30, 27 * portWORD_SIZE( sp )
    store_x x31, 28 * portWORD_SIZE( sp )
    call interrupt_handler
    load_x  x1, 1 * portWORD_SIZE( sp )
    load_x  x5, 2 * portWORD_SIZE( sp )		/* t0 */
    load_x  x6, 3 * portWORD_SIZE( sp )		/* t1 */
    load_x  x7, 4 * portWORD_SIZE( sp )		/* t2 */
    load_x  x8, 5 * portWORD_SIZE( sp )		/* s0/fp */
    load_x  x9, 6 * portWORD_SIZE( sp )		/* s1 */
    load_x  x10, 7 * portWORD_SIZE( sp )	/* a0 */
    load_x  x11, 8 * portWORD_SIZE( sp )	/* a1 */
    load_x  x12, 9 * portWORD_SIZE( sp )	/* a2 */
    load_x  x13, 10 * portWORD_SIZE( sp )	/* a3 */
    load_x  x14, 11 * portWORD_SIZE( sp )	/* a4 */
    load_x  x15, 12 * portWORD_SIZE( sp )	/* a5 */
    load_x  x16, 13 * portWORD_SIZE( sp )	/* a6 */
    load_x  x17, 14 * portWORD_SIZE( sp )	/* a7 */
    load_x  x18, 15 * portWORD_SIZE( sp )	/* s2 */
    load_x  x19, 16 * portWORD_SIZE( sp )	/* s3 */
    load_x  x20, 17 * portWORD_SIZE( sp )	/* s4 */
    load_x  x21, 18 * portWORD_SIZE( sp )	/* s5 */
    load_x  x22, 19 * portWORD_SIZE( sp )	/* s6 */
    load_x  x23, 20 * portWORD_SIZE( sp )	/* s7 */
    load_x  x24, 21 * portWORD_SIZE( sp )	/* s8 */
    load_x  x25, 22 * portWORD_SIZE( sp )	/* s9 */
    load_x  x26, 23 * portWORD_SIZE( sp )	/* s10 */
    load_x  x27, 24 * portWORD_SIZE( sp )	/* s11 */
    load_x  x28, 25 * portWORD_SIZE( sp )	/* t3 */
    load_x  x29, 26 * portWORD_SIZE( sp )	/* t4 */
    load_x  x30, 27 * portWORD_SIZE( sp )	/* t5 */
    load_x  x31, 28 * portWORD_SIZE( sp )	/* t6 */
    addi sp, sp, portCONTEXT_SIZE
    mret