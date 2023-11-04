library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
    generic (
        G_FREQ      : integer := 12e6;
        G_RAM_SIZE  : integer := 64*1024;
        G_INIT_FILE : string := "../../../../../../soft/bin/test.mem"
    );
    port (
        pin_arst_n_i : in std_logic;
        pin_clk_i : in std_logic;
        pin_uart_rx_i : in std_logic;
        pin_uart_tx_o : out std_logic
    );
end entity top;

architecture rtl of top is
    signal arst, arst_n : std_logic;
    signal clk : std_logic;
    signal pll_lock : std_logic;
    signal uart_tx, uart_rx : std_logic_vector(0 downto 0);
begin
    pll_lock <= '1';
    arst_n <= pin_arst_n_i and pll_lock;
    arst <= not arst_n;
    clk <= pin_clk_i;

    u_xtr_soc : entity work.xtr_soc
        generic map (
            G_FREQ_IN => G_FREQ, G_RAM_SIZE => G_RAM_SIZE, G_INIT_FILE => G_INIT_FILE,
            G_UART => 1, G_BOOT_TRAP => TRUE,
            G_CPU_BOOT_ADDRESS => x"00000000", G_CPU_PREFETCH_SIZE => 4,
            G_CPU_EXECUTE_BYPASS => TRUE, G_CPU_MEMORY_BYPASS => TRUE, G_CPU_WRITEBACK_BYPASS => TRUE,
            G_FULL_BARREL_SHIFTER => TRUE, G_CPU_SHIFTER_EARLY_INJECTION => FALSE,
            G_ZICSR => TRUE, G_EXTENSION_M => TRUE, G_EXTENSION_C => FALSE)
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            uart_rx_i => uart_rx, uart_tx_o => uart_tx, 
            external_irq_i => '0');

    pin_uart_tx_o <= uart_tx(0);
    uart_rx(0) <= pin_uart_rx_i;
    
end architecture rtl;