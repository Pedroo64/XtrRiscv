library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
    generic (
        C_FREQ      : integer := 100e6;
        C_RAM_SIZE  : integer := 32*1024;
        C_INIT_FILE : string := "../../../soft/bin/test.mem"
    );
    port (
        pin_arst_n_i : in std_logic;
        pin_clk_i : in std_logic;
        pin_btn_i : in std_logic_vector(3 downto 0);
        pin_rx_i : in std_logic;
        pin_tx_o : out std_logic
    );
end entity top;

architecture rtl of top is
    signal arst, arst_n : std_logic;
    signal clk : std_logic;
    signal uart_tx, uart_rx : std_logic_vector(0 downto 0);
    signal btn, d_btn : std_logic_vector(3 downto 0);
    signal external_irq : std_logic;
begin
    arst_n <= pin_arst_n_i;
    arst <= not arst_n;
    clk <= pin_clk_i;

    xtr_soc_inst : entity work.xtr_soc
        generic map (
            C_FREQ_IN => C_FREQ, C_RAM_SIZE => C_RAM_SIZE, C_INIT_FILE => C_INIT_FILE,
            C_UART => 1, C_BOOT_TRAP => TRUE)
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            uart_rx_i => uart_rx, uart_tx_o => uart_tx, 
            external_irq_i => external_irq);
    
    uart_rx(0) <= pin_rx_i;
    pin_tx_o <= uart_tx(0);

    process (clk, arst)
    begin
        if arst = '1' then
            btn <= (others => '0');
            d_btn <= (others => '0');
        elsif rising_edge(clk) then
            btn <= pin_btn_i;
            d_btn <= btn;
        end if;
    end process;
    external_irq <= 
        '1' when btn(0) = '1' and d_btn(0) = '0' else 
        '0';
      
end architecture rtl;