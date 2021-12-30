library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_instruction_fetch is
end entity tb_instruction_fetch;

architecture rtl of tb_instruction_fetch is
    constant C_CLK_PER               : time := 20 ns;
    signal arst                      : std_logic;
    signal clk                       : std_logic;
    signal t_en, en                  : std_logic;
    signal load_pc, decode_rdy       : std_logic;
    signal pc                        : std_logic_vector(31 downto 0);
    signal cmd_adr, rsp_dat          : std_logic_vector(31 downto 0);
    signal cmd_vld, cmd_rdy, rsp_vld : std_logic;
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

    process (clk, arst)
    begin
        if arst = '1' then
            cmd_rdy <= '0';
            rsp_vld <= '0';
            rsp_dat <= (others => '0');
            load_pc <= '0';
            pc <= (others => '0');
            en <= '0';
            decode_rdy <= '0';
        elsif rising_edge(clk) then
            cmd_rdy <= '1';
            decode_rdy <= '1';
            --en <= t_en;
            if cmd_vld = '1' then
                rsp_vld <= '1';
                rsp_dat <= std_logic_vector(unsigned(rsp_dat) + 1);
            else
                rsp_vld <= '0';
            end if;
            if unsigned(cmd_adr(7 downto 0)) = 16#30# and cmd_vld = '1' then
                load_pc <= '1';
                pc <= std_logic_vector(unsigned(pc) + x"100");
            else
                load_pc <= '0';
            end if;
            if unsigned(cmd_adr(7 downto 0)) = 16#10# and cmd_vld = '1' and decode_rdy = '1' then
                decode_rdy <= '0';
            else
                decode_rdy <= '1';
            end if;
            if unsigned(cmd_adr(7 downto 0)) = 16#20# and cmd_vld = '1' and en = '1' then
                en <= '0';
            else
                en <= '1';
            end if;
        end if;
    end process;
    p_rtl: process
    begin
        t_en <= '0';
        wait for 5*C_CLK_PER;
        t_en <= '1';
        wait;
    end process p_rtl;
    u_if : entity work.instruction_fecth
        port map(
            arst_i => arst, clk_i => clk, srst_i => '0',
            en_i => en,
            load_pc_i => load_pc, pc_i => pc,
            cmd_adr_o => cmd_adr, cmd_vld_o => cmd_vld, cmd_rdy_i => cmd_rdy, rsp_dat_i => rsp_dat, rsp_vld_i => rsp_vld,
            pc_o => open, instr_o => open, instr_vld_o => open, decode_rdy_i => decode_rdy);

end architecture rtl;