library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_soc is
    generic (
        C_FREQ_IN : integer := 50e6;
        C_RAM_SIZE : integer := 8192;
        C_INIT_FILE : string := "none";
        C_UART : integer range 0 to 4 := 4
    );
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        uart_rx_i : in std_logic_vector(C_UART - 1 downto 0);
        uart_tx_o : out std_logic_vector(C_UART - 1 downto 0);
        external_irq_i : in std_logic
    );
end entity xtr_soc;

architecture rtl of xtr_soc is
    signal instr_cmd, dat_cmd : xtr_cmd_t;
    signal instr_rsp, dat_rsp : xtr_rsp_t;
    signal xtr_cmd_lyr_1 : v_xtr_cmd_t(0 to 1);
    signal xtr_rsp_lyr_1 : v_xtr_rsp_t(0 to 1);
begin
    
    u_xtr_cpu : entity work.xtr_cpu
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            instr_cmd_o => instr_cmd, instr_rsp_i => instr_rsp,
            data_cmd_o => dat_cmd, data_rsp_i => dat_rsp,
            external_irq_i => external_irq_i);

    u_xtr_abr : entity work.xtr_abr
        generic map (
            C_MMSB => 31, C_MLSB => 32, C_SLAVES => 2)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0',
            xtr_cmd_i => dat_cmd, xtr_rsp_o => dat_rsp,
            v_xtr_cmd_o => xtr_cmd_lyr_1, v_xtr_rsp_i => xtr_rsp_lyr_1);

    u_xtr_ram : entity work.xtr_ram
        generic map (
            C_RAM_SIZE => C_RAM_SIZE, C_INIT_FILE => C_INIT_FILE)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            instr_cmd_i => instr_cmd, instr_rsp_o => instr_rsp,
            dat_cmd_i => xtr_cmd_lyr_1(0), dat_rsp_o => xtr_rsp_lyr_1(0));

    u_xtr_peripherials : entity work.xtr_peripherials
        generic map (
            C_FREQ_IN => C_FREQ_IN, C_UART => C_UART)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            xtr_cmd_i => xtr_cmd_lyr_1(1), xtr_rsp_o => xtr_rsp_lyr_1(1),
            uart_rx_i => uart_rx_i, uart_tx_o => uart_tx_o);
    
end architecture rtl;