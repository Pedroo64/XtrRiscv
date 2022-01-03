library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_cpu is
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        instr_cmd_o : out xtr_cmd_t;
        instr_rsp_i : in xtr_rsp_t;
        data_cmd_o : out xtr_cmd_t;
        data_rsp_i : in xtr_rsp_t
    );
end entity xtr_cpu;

architecture rtl of xtr_cpu is
    signal instr_cmd_adr, instr_rsp_dat : std_logic_vector(31 downto 0);
    signal instr_cmd_vld, instr_cmd_rdy, instr_rsp_vld : std_logic;
    signal data_cmd_adr, data_cmd_dat, data_rsp_dat : std_logic_vector(31 downto 0);
    signal data_cmd_vld, data_cmd_we, data_cmd_rdy, data_rsp_vld : std_logic;
    signal data_cmd_sel : std_logic_vector(3 downto 0);
begin
    
    u_cpu : entity work.cpu
    port map (
        arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
        instr_cmd_adr_o => instr_cmd_adr, instr_cmd_vld_o => instr_cmd_vld, 
        instr_cmd_rdy_i => instr_cmd_rdy, instr_rsp_dat_i => instr_rsp_dat, instr_rsp_vld_i => instr_rsp_vld,
        data_cmd_adr_o => data_cmd_adr, data_cmd_vld_o => data_cmd_vld, data_cmd_we_o => data_cmd_we, data_cmd_dat_o => data_cmd_dat,
        data_cmd_rdy_i => data_cmd_rdy, data_rsp_vld_i => data_rsp_vld, data_rsp_dat_i => data_rsp_dat);

    instr_cmd_o.adr <= instr_cmd_adr;
    instr_cmd_o.vld <= instr_cmd_vld;
    instr_cmd_o.we  <= '0';
    instr_cmd_o.dat <= (others => '0');
    instr_cmd_o.sel <= (others => '0');
    instr_cmd_rdy   <= instr_rsp_i.rdy;
    instr_rsp_vld   <= instr_rsp_i.vld;
    instr_rsp_dat   <= instr_rsp_i.dat;

    data_cmd_o.adr  <= data_cmd_adr;
    data_cmd_o.vld  <= data_cmd_vld;
    data_cmd_o.we   <= data_cmd_we;
    data_cmd_o.dat  <= data_cmd_dat;
    data_cmd_o.sel  <= (others => '1');
    data_cmd_rdy    <= data_rsp_i.rdy;
    data_rsp_vld    <= data_rsp_i.vld;
    data_rsp_dat    <= data_rsp_i.dat;
    
end architecture rtl;