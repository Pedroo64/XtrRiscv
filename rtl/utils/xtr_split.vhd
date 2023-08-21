library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;
use work.utils.all;

entity xtr_split is
    generic (
        G_BIT_PIVOT : integer := 31;
        G_SLAVES : integer := 2
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        v_xtr_cmd_o : out v_xtr_cmd_t(0 to G_SLAVES - 1);
        v_xtr_rsp_i : in v_xtr_rsp_t(0 to G_SLAVES - 1)
    );
end entity xtr_split;

architecture rtl of xtr_split is
    constant C_MSB : integer := G_BIT_PIVOT;
    constant C_LSB : integer := C_MSB - bit_width(G_SLAVES) + 1;
    signal last_xtr_cmd_adr : std_logic_vector(C_MSB downto C_LSB);
begin
    gen_cmd: for i in v_xtr_cmd_o'range generate
        v_xtr_cmd_o(i).adr <= xtr_cmd_i.adr;
        v_xtr_cmd_o(i).dat <= xtr_cmd_i.dat;
        v_xtr_cmd_o(i).sel <= xtr_cmd_i.sel;
        v_xtr_cmd_o(i).we <= xtr_cmd_i.we;
        v_xtr_cmd_o(i).vld <= xtr_cmd_i.vld when unsigned(xtr_cmd_i.adr(C_MSB downto C_LSB)) = i else '0';
    end generate gen_cmd;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if xtr_cmd_i.vld = '1' then
                last_xtr_cmd_adr <= xtr_cmd_i.adr(C_MSB downto C_LSB);
            end if;
        end if;
    end process;
    xtr_rsp_o.rdy <= v_xtr_rsp_i(to_integer(unsigned(xtr_cmd_i.adr(C_MSB downto C_LSB)))).rdy;
    xtr_rsp_o.vld <= v_xtr_rsp_i(to_integer(unsigned(last_xtr_cmd_adr))).vld;
    xtr_rsp_o.dat <= v_xtr_rsp_i(to_integer(unsigned(last_xtr_cmd_adr))).dat;
end architecture rtl;