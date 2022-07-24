library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package csr_def is
    
    constant CSR_MVENDORID  : std_logic_vector := x"F11";
    constant CSR_MARCHID    : std_logic_vector := x"F12";
    constant CSR_MIMPID     : std_logic_vector := x"F13";
    constant CSR_MHARTID    : std_logic_vector := x"F14";
    
    constant CSR_MSTATUS    : std_logic_vector := x"300";
    constant CSR_MISA       : std_logic_vector := x"301";
    constant CSR_MEDELEG    : std_logic_vector := x"302";
    constant CSR_MIDELEG    : std_logic_vector := x"303";
    constant CSR_MIE        : std_logic_vector := x"304";
    constant CSR_MTVEC      : std_logic_vector := x"305";
    
    constant CSR_MSCRATCH   : std_logic_vector := x"340";
    constant CSR_MEPC       : std_logic_vector := x"341";
    constant CSR_MCAUSE     : std_logic_vector := x"342";
    constant CSR_MTVAL      : std_logic_vector := x"343";
    constant CSR_MIP        : std_logic_vector := x"344";
    
    constant CSR_MBASE      : std_logic_vector := x"380";
    constant CSR_MBOUND     : std_logic_vector := x"381";
    constant CSR_MIBASE     : std_logic_vector := x"382";
    constant CSR_MIBOUND    : std_logic_vector := x"383";
    constant CSR_MDBASE     : std_logic_vector := x"384";
    constant CSR_MDBOUND    : std_logic_vector := x"385";

    constant CSR_MSTATUS_MIE : integer := 3;
    constant CSR_MIE_MEIE : integer := 11;
    constant CSR_MIE_MTIE : integer := 7;

-- Debug extension
    constant CSR_DCSR       : std_logic_vector := x"7B0";
    constant CSR_DPC        : std_logic_vector := x"7B1";
    constant CSR_DSCRATCH0  : std_logic_vector := x"7B2";
    constant CSR_DSCRATCH1  : std_logic_vector := x"7B3";
    constant CSR_DM_DATA0   : std_logic_vector := x"7C0";

-- mcause
    constant CSR_MCAUSE_USER_SOFTWARE_INTERRUPT         : std_logic_vector := x"80000000";
    constant CSR_MCAUSE_SUPERVISOR_SOFTWARE_INTERRUPT   : std_logic_vector := x"80000001";
    constant CSR_MCAUSE_HYPERVISOR_SOFTWARE_INTERRUPT   : std_logic_vector := x"80000002";
    constant CSR_MCAUSE_MACHINE_SOFTWARE_INTERRUPT      : std_logic_vector := x"80000003";
    constant CSR_MCAUSE_USER_TIMER_INTERRUPT            : std_logic_vector := x"80000004";
    constant CSR_MCAUSE_SUPERVISOR_TIMER_INTERRUPT      : std_logic_vector := x"80000005";
    constant CSR_MCAUSE_HYPERVISOR_TIMER_INTERRUPT      : std_logic_vector := x"80000006";
    constant CSR_MCAUSE_MACHINE_TIMER_INTERRUPT         : std_logic_vector := x"80000007";
    constant CSR_MCAUSE_USER_EXTERNAL_INTERRUPT         : std_logic_vector := x"80000008";
    constant CSR_MCAUSE_SUPERVISOR_EXTERNAL_INTERRUPT   : std_logic_vector := x"80000009";
    constant CSR_MCAUSE_HYPERVISOR_EXTERNAL_INTERRUPT   : std_logic_vector := x"8000000A";
    constant CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT      : std_logic_vector := x"8000000B";
    constant CSR_MCAUSE_INSTRUCTION_ADDRESS_MISALIGNED  : std_logic_vector := x"00000000";
    constant CSR_MCAUSE_INSTRUCTION_ACCESS_FAULT        : std_logic_vector := x"00000001";
    constant CSR_MCAUSE_ILLEGAL_INSTRUCTION             : std_logic_vector := x"00000002";
    constant CSR_MCAUSE_BREAKPOINT                      : std_logic_vector := x"00000003";
    constant CSR_MCAUSE_LOAD_ADDRESS_MISALIGNED         : std_logic_vector := x"00000004";
    constant CSR_MCAUSE_LOAD_ACCESS_FAULT               : std_logic_vector := x"00000005";
    constant CSR_MCAUSE_STORE_ADDRESS_MISALIGNED        : std_logic_vector := x"00000006";
    constant CSR_MCAUSE_STORE_ACCESS_FAULT              : std_logic_vector := x"00000007";
    constant CSR_MCAUSE_USER_ECALL                      : std_logic_vector := x"00000008";
    constant CSR_MCAUSE_SUPERVISOR_ECALL                : std_logic_vector := x"00000009";
    constant CSR_MCAUSE_HYPERVISOR_ECALL                : std_logic_vector := x"0000000A";
    constant CSR_MCAUSE_MACHINE_ECALL                   : std_logic_vector := x"0000000B";

end package csr_def;