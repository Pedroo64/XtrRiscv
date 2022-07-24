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
    signal t_debug_cmd, debug_cmd : xtr_cmd_t;
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
    process (clk, arst)
    begin
        if arst = '1' then
            debug_cmd.vld <= '0';
            debug_cmd.we <= '0';
        elsif rising_edge(clk) then
            debug_cmd <= t_debug_cmd;
        end if;
    end process;

    u_xtr_soc : entity work.sim_soc
        generic map (
            C_FREQ_IN => 50e6, C_RAM_SIZE => 16*1024*1024, C_INIT_FILE => C_INIT_FILE, C_OUTPUT_FILE => C_OUTPUT_FILE)
        port map (
            arst_i => arst, clk_i => clk, debug_cmd_i => debug_cmd, debug_rsp_o => debug_rsp);



    process
        procedure send_cmd (
            adr : std_logic_vector(7 downto 0);
            dat : std_logic_vector(31 downto 0);
            we : std_logic) is
        begin
            t_debug_cmd.vld <= '1'; t_debug_cmd.we <= we; t_debug_cmd.adr <= x"000000" & adr; t_debug_cmd.dat <= dat;
            wait for C_CLK_PER;
            t_debug_cmd.vld <= '0';
            wait for C_CLK_PER;
        end procedure;
        procedure send_cmd (
            adr : integer;
            dat : std_logic_vector(31 downto 0);
            we : std_logic) is
        begin
            send_cmd(std_logic_vector(to_unsigned(adr, 8)), dat, we);
        end procedure;
    begin
        t_debug_cmd.vld <= '0';
        wait for 20*C_CLK_PER;
        send_cmd(C_DMCONTROL, x"00000003", '1'); -- ndmreset, dmactive
        send_cmd(C_DMSTATUS, (others => '-'), '0'); -- read dmstatus
        send_cmd(C_DMCONTROL, x"00000001", '1'); -- dmactive
        send_cmd(C_DMSTATUS, (others => '-'), '0'); -- read dmstatus
        send_cmd(C_DMCONTROL, x"80000001", '1'); -- haltreq, dmactive
        send_cmd(C_DMSTATUS, (others => '-'), '0'); -- read dmstatus
        wait for 10*C_CLK_PER;
        send_cmd(C_COMMAND, x"00221002", '1'); -- should copy x2 into data0
        wait for 10*C_CLK_PER;
        send_cmd(C_DATA0, x"11223344", '1'); -- should copy x2 into data0
        send_cmd(C_COMMAND, x"00231002", '1'); -- should write data0 into x2
        wait for 10*C_CLK_PER;
        send_cmd(C_PROGBUF0, load_instruction(16#20#, 0, 2, 2), '1'); -- lw x2, x0(0x20)
        send_cmd(C_COMMAND, x"00240000", '1'); -- should execute progbuf
        wait for 10*C_CLK_PER;
        send_cmd(C_PROGBUF0, x"7b200073", '1'); -- dret
        send_cmd(C_COMMAND, x"00240000", '1'); -- should execute progbuf
        wait;
    end process;
end architecture rtl;