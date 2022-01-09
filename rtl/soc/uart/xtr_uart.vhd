library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;
use work.utils.all;

entity xtr_uart is
    generic (
        C_FREQ_IN : integer := 50e6;
        C_BAUD : integer := 115_200
    );
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        rx_i : in std_logic;
        tx_o : out std_logic
    );
end entity xtr_uart;

architecture rtl of xtr_uart is
    signal baud : std_logic_vector(15 downto 0);
    signal tx_vld, tx_rdy : std_logic;
    signal tx_dat : std_logic_vector(7 downto 0);
begin
    xtr_rsp_o.dat <= x"00000" & "000" & tx_rdy & x"00";
    xtr_rsp_o.rdy <= '1';
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            baud <= freq2slv(real(C_BAUD), real(C_FREQ_IN), baud'length);
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                baud <= freq2slv(real(C_BAUD), real(C_FREQ_IN), baud'length);
            else
                if xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '1' and xtr_cmd_i.sel(2) = '1' then
                    baud <= xtr_cmd_i.dat(15 downto 0);
                end if;
            end if;
        end if;
    end process;
    tx_vld <= 
        '1' when xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '1' and xtr_cmd_i.sel(0) = '1' else 
        '0';
    tx_dat <= xtr_cmd_i.dat(7 downto 0);
    u_uart_tx : entity work.uart_tx
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            baud => baud, rdy_o => tx_rdy,
            tx_vld_i => tx_vld, tx_dat_i => tx_dat, 
            tx_o => tx_o);
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            xtr_rsp_o.vld <= xtr_cmd_i.vld;
        end if;
    end process;

    
end architecture rtl;