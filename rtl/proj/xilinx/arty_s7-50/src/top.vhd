library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
    generic (
        C_FREQ      : integer := 100e6;
        C_RAM_SIZE  : integer := 32*1024;
        C_INIT_FILE : string := "E:/Dev/XtrRiscv/soft/bin/test.mem"
    );
    port (
        pin_arst_n_i    : in std_logic;
        pin_clk_i       : in std_logic;
        pin_rx_i        : in std_logic;
        pin_tx_o        : out std_logic
    );
end entity top;

architecture rtl of top is
    signal arst, arst_n : std_logic;
    signal clk : std_logic;
    signal uart_tx, uart_rx : std_logic_vector(0 downto 0);
begin
    arst_n <= pin_arst_n_i;
    arst <= not arst_n;
    clk <= pin_clk_i;

    xtr_soc_inst : entity work.xtr_soc
    generic map (
        C_FREQ_IN => C_FREQ, C_RAM_SIZE => C_RAM_SIZE, C_INIT_FILE => C_INIT_FILE,
        C_UART => 1)
    port map (
        arst_i => arst, clk_i => clk, srst_i => '0',
        uart_rx_i => uart_rx, uart_tx_o => uart_tx);
    
    uart_rx(0) <= pin_rx_i;
    pin_tx_o <= uart_tx(0);
      
end architecture rtl;