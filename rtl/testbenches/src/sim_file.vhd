library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.xtr_def.all;

entity sim_file is
    generic (
        C_OUTPUT_FILE : string
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t
    );
end entity sim_file;

architecture rtl of sim_file is
    signal mode : std_logic_vector(0 downto 0);
begin
    
    process (clk_i)
        variable c : character;
        variable int : integer;
        variable str : line;
        file file_handler : text open write_mode is C_OUTPUT_FILE;
    begin
        if rising_edge(clk_i) then
            if xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '1' then
                int := to_integer(unsigned(xtr_cmd_i.dat(7 downto 0)));
                c := character'val(int);
                write(str, c);
                write(file_handler, str.all);
                deallocate(str);   
            end if;
        end if;
    end process;

    xtr_rsp_o.rdy <= '1';
    xtr_rsp_o.vld <= '0';
    xtr_rsp_o.dat <= (others => '0');

end architecture rtl;