library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package xtr_def is
    
    type xtr_cmd_t is record
        adr, dat : std_logic_vector(31 downto 0);
        sel : std_logic_vector(3 downto 0);
        vld, we : std_logic;
    end record xtr_cmd_t;
    type xtr_rsp_t is record
        rdy, vld : std_logic;
        dat : std_logic_vector(31 downto 0);
    end record xtr_rsp_t;

    type v_xtr_cmd_t is array (natural range <>) of xtr_cmd_t;
    type v_xtr_rsp_t is array (natural range <>) of xtr_rsp_t;

    
end package xtr_def;