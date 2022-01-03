.global crtStart
.section .text
crtStart:
    li x5, 0x10 # x5 = 0x10
    li x6, 0x20 # x6 = 0x20
    add x5, x5, x6; # x5 = x5 + x6
    sw x5, 0x100(x0) # 
    lw x6, 0x100(x0) #
    addi x10, x6, 0x10; # x10 = x6 + 0x10 
    li x11, 0x20 # x2 = 0x20
    jal addition  # jump to addition and save position to ra
    sw x10, 0x100(x0) #
    lw x6, 0x100(x0) #
test:
    beq x6, x0, test; # if x6 == x0 then test
    and x5, x5, x6
    or x5, x5, x6
    xor x5, x5, x6
    not x5, x5
    
infinitLoop:
    j infinitLoop

addition:
    add x10, x10, x11; # x10 = x10 + x11
    ret
    li x31, 0x10 # x31 = 0x10
    