library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_xtr_soc is
    generic (
        G_INIT_FILE : string := "none";
        G_OUTPUT_FILE : string := "none";
        G_EXECUTE_BYPASS : boolean := FALSE;
        G_MEMORY_BYPASS : boolean := FALSE;
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE
    );
end entity tb_xtr_soc;

architecture rtl of tb_xtr_soc is
    constant C_CLK_PER : time   := 20 ns;
    signal arst : std_logic;
    signal clk : std_logic;
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
            G_FREQ_IN => 50e6, G_RAM_SIZE => 2*1024*1024, G_INIT_FILE => G_INIT_FILE, G_OUTPUT_FILE => G_OUTPUT_FILE, 
            G_CPU_BOOT_ADDRESS => x"00000000", G_CPU_EXECUTE_BYPASS => G_EXECUTE_BYPASS, G_CPU_MEMORY_BYPASS => G_MEMORY_BYPASS, G_CPU_WRITEBACK_BYPASS => G_WRITEBACK_BYPASS, G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER)
        port map (
            arst_i => arst, clk_i => clk, external_irq_i => interrupt);
end architecture rtl;