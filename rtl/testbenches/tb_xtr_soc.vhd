library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;
use work.debug_module_pkg.all;

entity tb_xtr_soc is
    generic (
        C_INIT_FILE : string := "none";
        C_OUTPUT_FILE : string := "none"
    );
end entity tb_xtr_soc;

architecture rtl of tb_xtr_soc is
    constant C_CLK_PER   : time   := 20 ns;
    signal arst          : std_logic;
    signal clk           : std_logic;
    signal t_interrupt, interrupt : std_logic := '0';
    signal debug_cmd : xtr_cmd_t;
    signal debug_rsp : xtr_rsp_t;
    function load_instruction (
        imm : integer;
        rs1 : integer;
        size : integer;
        rd : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(imm, 12) & to_unsigned(rs1, 5) & to_unsigned(size, 3) & to_unsigned(rd, 5) & "0000011");
    end function;
begin

    p_arst : process
    begin
        arst <= '1';
        wait for 63 ns;
        arst <= '0';
        wait;
    end process p_arst;

    p_clk : process
    begin
        clk <= '0';
        wait for C_CLK_PER / 2;
        clk <= '1';
        wait for C_CLK_PER / 2;
    end process p_clk;

    p_interrupt: process
    begin
        t_interrupt <= '0';
        wait for 68*C_CLK_PER;
        t_interrupt <= '1';
        wait for C_CLK_PER;
        t_interrupt <= '0';
    end process p_interrupt;
    process (clk)
    begin
        if rising_edge(clk) then
            interrupt <= t_interrupt;
        end if;
    end process;

    u_xtr_soc : entity work.sim_soc
        generic map (
            C_FREQ_IN => 50e6, C_RAM_SIZE => 16*1024*1024, C_INIT_FILE => C_INIT_FILE, C_OUTPUT_FILE => C_OUTPUT_FILE)
        port map (
            arst_i => arst, clk_i => clk, debug_cmd_i => debug_cmd, debug_rsp_o => debug_rsp);

block_dtm : block
    signal tck, tdi, tdo, tms : std_logic;
begin
    debug_cmd.adr(31 downto 8) <= (others => '0');
    u_jtag_dtm : entity work.jtag_dtm
        port map (
            arst_i => arst,
            clk_i => clk,
            tck_i => tck,
            tdi_i => tdi,
            tdo_o => tdo,
            tms_i => tms,
            cmd_adr_o => debug_cmd.adr(7 downto 0),
            cmd_dat_o => debug_cmd.dat,
            cmd_vld_o => debug_cmd.vld,
            cmd_we_o => debug_cmd.we,
            rsp_rdy_i => debug_rsp.rdy,
            rsp_vld_i => debug_rsp.vld,
            rsp_dat_i => debug_rsp.dat
        );
    u_sim_jtag : entity work.sim_jtag
        port map (
            arst_i => arst,
            clk_i => clk,
            tck_o => tck,
            tdi_o => tdi,
            tms_o => tms,
            tdo_i => tdo
        );
end block;
          

end architecture rtl;