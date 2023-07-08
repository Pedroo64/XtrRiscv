library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_soc is
    generic (
        G_FREQ_IN : integer := 50e6;
        G_RAM_SIZE : integer := 8192;
        G_INIT_FILE : string := "none";
        G_UART : integer range 0 to 4 := 4;
        G_BOOT_TRAP : boolean := false;
        G_CPU_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_CPU_EXECUTE_BYPASS : boolean := FALSE;
        G_CPU_MEMORY_BYPASS : boolean := FALSE;
        G_CPU_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE
    );
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        uart_rx_i : in std_logic_vector(G_UART - 1 downto 0);
        uart_tx_o : out std_logic_vector(G_UART - 1 downto 0);
        external_irq_i : in std_logic
    );
end entity xtr_soc;

architecture rtl of xtr_soc is
    signal sys_rst : std_logic;
    signal rst_hold : std_logic_vector(3 downto 0);
    signal instr_cmd, dat_cmd : xtr_cmd_t;
    signal instr_rsp, dat_rsp : xtr_rsp_t;
    signal xtr_cmd_lyr_1 : v_xtr_cmd_t(0 to 1);
    signal xtr_rsp_lyr_1 : v_xtr_rsp_t(0 to 1);
    signal xtr_cmd_lyr_2 : v_xtr_cmd_t(0 to 1);
    signal xtr_rsp_lyr_2 : v_xtr_rsp_t(0 to 1);
    signal timer_irq, external_irq : std_logic;
    signal rst_rq : std_logic;
begin
    -- Hold reset for at least 4 clock cycles
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if arst_i = '1' or rst_rq = '1' then
                rst_hold <= (others => '1');
            elsif rst_hold(3) = '1' then
                rst_hold <= rst_hold(2 downto 0) & '0';
            end if;
        end if;
    end process;
    sys_rst <= rst_hold(rst_hold'left) or srst_i;

    u_xtr_cpu : entity work.xtr_cpu
        generic map (
            G_BOOT_ADDRESS => G_CPU_BOOT_ADDRESS,
            G_EXECUTE_BYPASS => G_CPU_EXECUTE_BYPASS,
            G_MEMORY_BYPASS => G_CPU_MEMORY_BYPASS,
            G_WRITEBACK_BYPASS => G_CPU_WRITEBACK_BYPASS,
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER
        )
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => sys_rst,
            instr_cmd_o => instr_cmd, instr_rsp_i => instr_rsp,
            data_cmd_o => dat_cmd, data_rsp_i => dat_rsp,
            external_irq_i => external_irq, timer_irq_i => timer_irq);

    u_xtr_abr : entity work.xtr_abr
        generic map (
            C_MMSB => 31, C_MLSB => 32, C_SLAVES => 2)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0',
            xtr_cmd_i => dat_cmd, xtr_rsp_o => dat_rsp,
            v_xtr_cmd_o => xtr_cmd_lyr_1, v_xtr_rsp_i => xtr_rsp_lyr_1);

    u_xtr_ram : entity work.xtr_ram
        generic map (
            C_RAM_SIZE => G_RAM_SIZE, C_INIT_FILE => G_INIT_FILE)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            instr_cmd_i => instr_cmd, instr_rsp_o => instr_rsp,
            dat_cmd_i => xtr_cmd_lyr_1(0), dat_rsp_o => xtr_rsp_lyr_1(0));

    u_xtr_peripherials : entity work.xtr_peripherials
        generic map (
            C_FREQ_IN => G_FREQ_IN, C_UART => G_UART, C_BOOT_TRAP => G_BOOT_TRAP)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => sys_rst,
            xtr_cmd_i => xtr_cmd_lyr_1(1), xtr_rsp_o => xtr_rsp_lyr_1(1),
            uart_rx_i => uart_rx_i, uart_tx_o => uart_tx_o,
            timer_irq_o => timer_irq, external_irq_o => open, rst_rq_o => rst_rq);

    external_irq <= external_irq_i;

    
end architecture rtl;