library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_peripherials is
    generic (
        C_FREQ_IN : integer := 50e6;
        C_UART : integer range 0 to 4 := 4;
        C_BOOT_TRAP : boolean := false
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        uart_rx_i : in std_logic_vector(C_UART - 1 downto 0);
        uart_tx_o : out std_logic_vector(C_UART - 1 downto 0);
        timer_irq_o : out std_logic;
        external_irq_o : out std_logic;
        rst_rq_o : out std_logic
    );
end entity xtr_peripherials;

architecture rtl of xtr_peripherials is
    signal v_xtr_cmd_lyr3 : v_xtr_cmd_t(0 to 7);
    signal v_xtr_rsp_lyr3 : v_xtr_rsp_t(0 to 7);
    -- UART
    signal v_uart_xtr_cmd : v_xtr_cmd_t(0 to 3);
    signal v_uart_xtr_rsp : v_xtr_rsp_t(0 to 3);
    signal uart_irq : std_logic_vector(3 downto 0);
    signal uart_status : std_logic_vector(4*2 - 1 downto 0);
    -- Timer
    signal v_timer_xtr_cmd : v_xtr_cmd_t(0 to 7);
    signal v_timer_xtr_rsp : v_xtr_rsp_t(0 to 7);
    signal timer_irq :  std_logic_vector(7 downto 0);
    -- Boot trap
    signal boot_trap_rst_rqst  : std_logic;
begin
    
    -- Peripherials
    -- CXXX XXXX XXXX F000
    -- FXXX XXXX XXXX FFFF
    u_xtr_spliter_lyr3 : entity work.xtr_abr
        generic map (
            C_MMSB => 11, C_MLSB => 12, C_MASK => x"FFFFF000", C_SLAVES => 8)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0',
            xtr_cmd_i => xtr_cmd_i, xtr_rsp_o => xtr_rsp_o,
            v_xtr_cmd_o => v_xtr_cmd_lyr3, v_xtr_rsp_i => v_xtr_rsp_lyr3);

    -- UART
    -- CXXX XXXX XXXX FB00
    -- FXXX XXXX XXXX FBFF
    u_xtr_abr_uart : entity work.xtr_abr
        generic map (
            C_MMSB => 9, C_MLSB => 8,  C_MASK => x"FFFFFB00", C_SLAVES  => 4)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0', 
            xtr_cmd_i => v_xtr_cmd_lyr3(5), xtr_rsp_o  => v_xtr_rsp_lyr3(5),
            v_xtr_cmd_o => v_uart_xtr_cmd, v_xtr_rsp_i => v_uart_xtr_rsp);
    gen_uart: for i in 1 to C_UART generate        
        uXtrUart : entity work.xtr_uart
            generic map (
                C_FREQ_IN => C_FREQ_IN, C_BAUD => 115_200)
            port map (
                arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
                xtr_cmd_i => v_uart_xtr_cmd(i - 1), xtr_rsp_o  => v_uart_xtr_rsp(i - 1),
                status_o => uart_status(2*(i-1) + 1 downto 2*(i-1)),
                rx_i => uart_rx_i(i - 1), tx_o => uart_tx_o(i - 1), irq_o => uart_irq(i - 1));
    end generate gen_uart;
            
--    u_xtr_uart : entity work.xtr_uart
--        generic map (
--            C_FREQ_IN => C_FREQ_IN, C_BAUD => 115_200)
--        port map (
--            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
--            xtr_cmd_i => xtr_cmd_i, xtr_rsp_o => xtr_rsp_o,
--            rx_i => uart_rx_i(0), tx_o => uart_tx_o(0));

    -- Timers
    -- CXXX XXXX XXXX F400
    -- FXXX XXXX XXXX F5FF 
    u_xtr_abr_timer : entity work.xtr_abr
        generic map (
            C_MMSB => 9, C_MLSB => 8, C_MASK => x"FFFFF400", C_SLAVES  => 8)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0', 
            xtr_cmd_i => v_xtr_cmd_lyr3(2), xtr_rsp_o => v_xtr_rsp_lyr3(2),
            v_xtr_cmd_o => v_timer_xtr_cmd, v_xtr_rsp_i => v_timer_xtr_rsp);

    u_mtime : entity work.xtr_mtime
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            xtr_cmd_i => v_timer_xtr_cmd(0), xtr_rsp_o => v_timer_xtr_rsp(0),
            irq_o => timer_irq(0));

    gen_boot_trap: if C_BOOT_TRAP = TRUE and C_UART >= 1 generate
        -- Boot trap
        -- CXXX XXXX XXXX FE00
        -- FXXX XXXX XXXX FFFF 
        u_xtr_boot_trap : entity work.xtr_boot_trap
            port map (
                arst_i => arst_i, clk_i => clk_i, srst_i => '0',
                xtr_cmd_i => v_xtr_cmd_lyr3(7), xtr_rsp_o => v_xtr_rsp_lyr3(7),
                baud_en_i => uart_status(1), rx_vld_i => uart_status(0), rx_dat_i => v_uart_xtr_rsp(0).dat(7 downto 0),
                trap_o => boot_trap_rst_rqst);
    end generate gen_boot_trap;
            
    rst_rq_o <= boot_trap_rst_rqst;
    timer_irq_o <= timer_irq(0);    
            
end architecture rtl;