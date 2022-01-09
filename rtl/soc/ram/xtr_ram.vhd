library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.xtr_def.all;

entity xtr_ram is
    generic (
        C_RAM_SIZE : integer := 8192;
        C_INIT_FILE : string := "none"
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        instr_cmd_i : in xtr_cmd_t;
        instr_rsp_o : out xtr_rsp_t;
        dat_cmd_i : in xtr_cmd_t;
        dat_rsp_o : out xtr_rsp_t
    );
end entity xtr_ram;

architecture rtl of xtr_ram is
    constant C_ADDR_DEPTH : integer := integer(log2(real(C_RAM_SIZE)));
begin
    
    u_bram : entity work.bram
        generic map (
            C_DEPTH => C_RAM_SIZE / 4, C_INIT_FILE => C_INIT_FILE,
            C_ADDR_A_WIDTH => C_ADDR_DEPTH, C_DATA_A_WIDTH => 32, C_BYTE_A_WIDTH => 8,
            C_ADDR_B_WIDTH => C_ADDR_DEPTH, C_DATA_B_WIDTH => 32, C_BYTE_B_WIDTH => 8)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            addr_a_i => instr_cmd_i.adr(C_ADDR_DEPTH + 1 downto 2), en_a_i => instr_cmd_i.vld, we_a_i => '0', be_a_i => instr_cmd_i.sel, dat_a_i => (others => '0'), dat_a_o => instr_rsp_o.dat,
            addr_b_i => dat_cmd_i.adr(C_ADDR_DEPTH + 1 downto 2), en_b_i => dat_cmd_i.vld, we_b_i => dat_cmd_i.we, be_b_i => dat_cmd_i.sel, dat_b_i => dat_cmd_i.dat, dat_b_o => dat_rsp_o.dat);
    instr_rsp_o.rdy <= '1';
    dat_rsp_o.rdy <= '1';

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            instr_rsp_o.vld <= '0';
            dat_rsp_o.vld <= '0';
        elsif rising_edge(clk_i) then
            instr_rsp_o.vld <= instr_cmd_i.vld;
            dat_rsp_o.vld <= dat_cmd_i.vld;
        end if;
    end process;
    
end architecture rtl;