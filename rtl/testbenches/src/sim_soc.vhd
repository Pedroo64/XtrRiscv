library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity sim_soc is
    generic (
        C_FREQ_IN : integer := 50e6;
        C_RAM_SIZE : integer := 8192;
        C_INIT_FILE : string := "none";
        C_OUTPUT_FILE : string
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        external_irq_i : in std_logic
    );
end entity sim_soc;

architecture rtl of sim_soc is
    signal sys_rst : std_logic;
    signal rst_hold : std_logic_vector(3 downto 0);
    signal instr_cmd, dat_cmd : xtr_cmd_t;
    signal instr_rsp, dat_rsp : xtr_rsp_t;
    signal xtr_cmd_lyr_1 : v_xtr_cmd_t(0 to 1);
    signal xtr_rsp_lyr_1 : v_xtr_rsp_t(0 to 1);
    signal xtr_cmd_lyr_2 : v_xtr_cmd_t(0 to 3);
    signal xtr_rsp_lyr_2 : v_xtr_rsp_t(0 to 3);
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
    sys_rst <= rst_hold(rst_hold'left);

    u_xtr_cpu : entity work.xtr_cpu
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => sys_rst,
            instr_cmd_o => instr_cmd, instr_rsp_i => instr_rsp,
            data_cmd_o => dat_cmd, data_rsp_i => dat_rsp,
            external_irq_i => external_irq_i, timer_irq_i => '0');

    u_xtr_abr_lyr1 : entity work.xtr_abr
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
            arst_i => arst_i, clk_i => clk_i, srst_i => '0',
            instr_cmd_i => instr_cmd, instr_rsp_o => instr_rsp,
            dat_cmd_i => xtr_cmd_lyr_1(0), dat_rsp_o => xtr_rsp_lyr_1(0));

    -- 8XXX XXX0 0000 0000
    -- FXXX XXX3 FFFF FFFF
    u_xtr_abr_lyr2 : entity work.xtr_abr
        generic map (
            C_MMSB => 17, C_MLSB => 18, C_SLAVES => 4)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0',
            xtr_cmd_i => xtr_cmd_lyr_1(1), xtr_rsp_o => xtr_rsp_lyr_1(1),
            v_xtr_cmd_o => xtr_cmd_lyr_2, v_xtr_rsp_i => xtr_rsp_lyr_2);

    -- 8XXX XXX0 0000 0000
    -- FXXX XXX0 FFFF FFFF
    u_sim_stdout : entity work.sim_stdout
        port map (
            arst_i => arst_i, clk_i => clk_i,
            xtr_cmd_i => xtr_cmd_lyr_2(0), xtr_rsp_o => xtr_rsp_lyr_2(0));
    
    gen_file_output: if C_OUTPUT_FILE /= "none" generate
        -- 8XXX XXX1 0000 0000
        -- FXXX XXX1 FFFF FFFF
        u_sim_file : entity work.sim_file
            generic map (
                C_OUTPUT_FILE => C_OUTPUT_FILE)
            port map (
                arst_i => arst_i, clk_i => clk_i,
                xtr_cmd_i => xtr_cmd_lyr_2(1), xtr_rsp_o => xtr_rsp_lyr_2(1));        
    end generate gen_file_output;


    -- 8XXX XXX2 0000 0000
    -- FXXX XXX2 FFFF FFFF
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if xtr_cmd_lyr_2(2).vld = '1' and xtr_cmd_lyr_2(2).we = '1' then
                if xtr_cmd_lyr_2(2).dat = x"CAFECAFE" and xtr_cmd_lyr_2(2).sel = x"F" then
                    assert false report "Finished simulation" severity failure;
                end if;
            end if;
        end if;
    end process;


end architecture rtl;