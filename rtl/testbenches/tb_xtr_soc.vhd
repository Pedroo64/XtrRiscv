library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_xtr_soc is
end entity tb_xtr_soc;

architecture rtl of tb_xtr_soc is
    constant C_INIT_FILE : string := "E:/Dev/XtrRiscv/soft/bin/test.mem";
    constant C_CLK_PER   : time   := 20 ns;
    signal arst          : std_logic;
    signal clk           : std_logic;
    signal t_interrupt, interrupt : std_logic := '0';
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
        wait for 92*C_CLK_PER;
        t_interrupt <= '0';
        wait for C_CLK_PER;
        t_interrupt <= '0';
    end process p_interrupt;
    process (clk)
    begin
        if rising_edge(clk) then
            interrupt <= t_interrupt;
        end if;
    end process;

    u_xtr_soc : entity work.xtr_soc
        generic map (
            C_FREQ_IN => 50e6, C_RAM_SIZE => 16*1024, C_UART => 1, C_INIT_FILE => C_INIT_FILE)
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            uart_rx_i => (others => '1'), uart_tx_o => open,
            external_irq_i => interrupt);

end architecture rtl;