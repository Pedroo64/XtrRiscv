library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_peripherials is
    generic (
        C_FREQ_IN : integer := 50e6;
        C_UART : integer range 0 to 4 := 4
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        uart_rx_i : in std_logic_vector(C_UART - 1 downto 0);
        uart_tx_o : out std_logic_vector(C_UART - 1 downto 0)
    );
end entity xtr_peripherials;

architecture rtl of xtr_peripherials is
    
begin
    
    u_xtr_uart : entity work.xtr_uart
        generic map (
            C_FREQ_IN => C_FREQ_IN, C_BAUD => 115_200)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            xtr_cmd_i => xtr_cmd_i, xtr_rsp_o => xtr_rsp_o,
            rx_i => uart_rx_i(0), tx_o => uart_tx_o(0));

end architecture rtl;