.global crtStart
.section .text
crtStart:
    la x1, 0x10 # 
    add x1, x1, x2; # x1 = x1 + x2
    addi x2, x2, 0x20; # x2 = x2 + 0x20
    la x3, 0x30 # 
    li x4, 0x100 # x4 = 0x100
     
    
infinitLoop:
    j infinitLoop