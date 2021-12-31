.global crtStart
.section .text
crtStart:
    la x1, 0x10 # 
    add x1, x1, x2; # x1 = x1 + x2
    addi x2, x2, 0x20; # x2 = x2 + 0x20
    la x3, 0x30 # 
    li x4, 0x100 # x4 = 0x100
    sw x5, 0x20(x4) # 
    lb x6, 0x4(x5) # 
    sh x7, 0x8(x6)
    la x1, 0x10 # 
    li x2, 0x4 # x2 = 0x4
    
    la x1, 0x10 # 
    add x1, x1, x2; # x1 = x1 + x2
    addi x2, x2, 0x20; # x2 = x2 + 0x20
    la x3, 0x30 # 
    li x4, 0x100 # x4 = 0x100
    sw x5, 0x20(x4) # 
    lb x6, 0x4(x5) # 
    sh x7, 0x8(x6)
    la x1, 0x10 # 
    li x2, 0x4 # x2 = 0x4
    
    
    
infinitLoop:
    j infinitLoop