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
    constant CSR_MBADADDR   : std_logic_vector := x"343";
    constant CSR_MIP        : std_logic_vector := x"344";
    
    constant CSR_MBASE      : std_logic_vector := x"380";
    constant CSR_MBOUND     : std_logic_vector := x"381";
    constant CSR_MIBASE     : std_logic_vector := x"382";
    constant CSR_MIBOUND    : std_logic_vector := x"383";
    constant CSR_MDBASE     : std_logic_vector := x"384";
    constant CSR_MDBOUND    : std_logic_vector := x"385";

    constant CSR_MSTATUS_MIE : integer := 3;
    constant CSR_MIE_MEIE : integer := 11;

end package csr_def;