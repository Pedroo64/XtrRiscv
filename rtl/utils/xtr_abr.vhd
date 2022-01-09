library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;
use work.utils.all;

entity xtr_abr is
    generic (
        C_MMSB : integer := 31;
        C_MLSB : integer := 16;
        C_MASK : std_logic_vector(31 downto 0) := (others => '1');
        C_SLAVES : integer := 4
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        v_xtr_cmd_o : out v_xtr_cmd_t(0 to C_SLAVES - 1);
        v_xtr_rsp_i : in v_xtr_rsp_t(0 to C_SLAVES - 1)
    );
end entity xtr_abr;

architecture rtl of xtr_abr is
    constant C_SMSB : integer := C_MLSB - 1;
    constant C_SLSB : integer := C_MLSB - bit_width(C_SLAVES);
    signal last_xtr_cmd_adr : std_logic_vector(31 downto 0);
begin
    
    gen_cmd: for i in 0 to C_SLAVES - 1 generate
        v_xtr_cmd_o(i).adr <= xtr_cmd_i.adr;
        v_xtr_cmd_o(i).dat <= xtr_cmd_i.dat;
        v_xtr_cmd_o(i).we  <= xtr_cmd_i.we;
        v_xtr_cmd_o(i).sel <= xtr_cmd_i.sel;
        gen_without_mask : if C_MMSB < C_MLSB generate
            v_xtr_cmd_o(i).vld <= 
                xtr_cmd_i.vld when unsigned(xtr_cmd_i.adr(C_SMSB downto C_SLSB)) = i else
                '0';
        end generate gen_without_mask;
        gen_with_mask : if C_MMSB >= C_MLSB generate
            v_xtr_cmd_o(i).vld <= 
                xtr_cmd_i.vld when xtr_cmd_i.adr(C_MMSB downto C_MLSB) = C_MASK(C_MMSB downto C_MLSB) and unsigned(xtr_cmd_i.adr(C_SMSB downto C_SLSB)) = i else
                '0';
        end generate gen_with_mask;
    end generate gen_cmd;
    
    xtr_rsp_o.rdy <= v_xtr_rsp_i(to_integer(unsigned(xtr_cmd_i.Adr(C_SMSB downto C_SLSB)))).rdy when unsigned(xtr_cmd_i.Adr(C_SMSB downto C_SLSB)) <= (C_SLAVES - 1) else '0';
    xtr_rsp_o.vld <= v_xtr_rsp_i(to_integer(unsigned(last_xtr_cmd_adr(C_SMSB downto C_SLSB)))).vld;
    xtr_rsp_o.dat <= v_xtr_rsp_i(to_integer(unsigned(last_xtr_cmd_adr(C_SMSB downto C_SLSB)))).dat;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            last_xtr_cmd_adr <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                last_xtr_cmd_adr <= (others => '0');
            else
                if xtr_cmd_i.vld = '1' and unsigned(xtr_cmd_i.adr(C_SMSB downto C_SLSB)) <= (C_SLAVES - 1) then
                    last_xtr_cmd_adr <= xtr_cmd_i.adr;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;