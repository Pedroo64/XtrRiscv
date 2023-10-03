library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity sim_soc is
    generic (
        G_FREQ_IN : integer := 50e6;
        G_RAM_SIZE : integer := 8192;
        G_INIT_FILE : string := "none";
        G_OUTPUT_FILE : string;
        G_CPU_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_CPU_EXECUTE_BYPASS : boolean := FALSE;
        G_CPU_MEMORY_BYPASS : boolean := FALSE;
        G_CPU_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_CPU_SHIFTER_EARLY_INJECTION : boolean := FALSE;
        G_ZICSR : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE
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
    signal xtr_rsp_lyr_1 : v_xtr_rsp_t(0 to 1) := (others => (vld => '0', rdy => '1', dat => (others => '0')));
    signal xtr_cmd_lyr_2 : v_xtr_cmd_t(0 to 7);
    signal xtr_rsp_lyr_2 : v_xtr_rsp_t(0 to 7) := (others => (vld => '0', rdy => '1', dat => (others => '0')));
    signal timer_irq, external_irq : std_logic;
    signal rst_rq : std_logic;
    type memory_command_st_t is (st_idle, st_delay_cmd, st_delay_read);
    signal memory_current_st : memory_command_st_t;
    signal memory_test_delay_cnt : unsigned(5 downto 0) := (others => '0');
    signal memory_test_reg : std_logic_vector(31 downto 0) := (others => '0');
-- external irq
    signal irq_cnt : unsigned(12 downto 0);
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
        generic map (
            G_BOOT_ADDRESS => G_CPU_BOOT_ADDRESS,
            G_EXECUTE_BYPASS => G_CPU_EXECUTE_BYPASS,
            G_MEMORY_BYPASS => G_CPU_MEMORY_BYPASS,
            G_WRITEBACK_BYPASS => G_CPU_WRITEBACK_BYPASS,
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER,
            G_SHIFTER_EARLY_INJECTION => G_CPU_SHIFTER_EARLY_INJECTION,
            G_ZICSR => G_ZICSR,
            G_EXTENSION_M => G_EXTENSION_M
        )
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => sys_rst,
            instr_cmd_o => instr_cmd, instr_rsp_i => instr_rsp,
            data_cmd_o => dat_cmd, data_rsp_i => dat_rsp,
            external_irq_i => external_irq, timer_irq_i => timer_irq);

    u_xtr_split_lyr1 : entity work.xtr_split
        generic map (
            G_BIT_PIVOT => 31, G_SLAVES => 2)
        port map (
            arst_i => arst_i, clk_i => clk_i,
            xtr_cmd_i => dat_cmd, xtr_rsp_o => dat_rsp,
            v_xtr_cmd_o => xtr_cmd_lyr_1, v_xtr_rsp_i => xtr_rsp_lyr_1);

    u_xtr_ram : entity work.xtr_ram
        generic map (
            C_RAM_SIZE => G_RAM_SIZE, C_INIT_FILE => G_INIT_FILE)
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => '0',
            instr_cmd_i => instr_cmd, instr_rsp_o => instr_rsp,
            dat_cmd_i => xtr_cmd_lyr_1(0), dat_rsp_o => xtr_rsp_lyr_1(0));

    -- 8XX0 0000
    -- FXX7 FFFF
    u_xtr_split_lyr2 : entity work.xtr_split
        generic map (
            G_BIT_PIVOT => 18, G_SLAVES => 8)
        port map (
            arst_i => arst_i, clk_i => clk_i,
            xtr_cmd_i => xtr_cmd_lyr_1(1), xtr_rsp_o => xtr_rsp_lyr_1(1),
            v_xtr_cmd_o => xtr_cmd_lyr_2, v_xtr_rsp_i => xtr_rsp_lyr_2);

    -- 8XX0 0000
    -- FXX0 FFFF
    u_sim_stdout : entity work.sim_stdout
        port map (
            arst_i => arst_i, clk_i => clk_i,
            xtr_cmd_i => xtr_cmd_lyr_2(0), xtr_rsp_o => xtr_rsp_lyr_2(0));
    
    gen_file_output: if G_OUTPUT_FILE /= "none" generate
        -- 8XX1 0000
        -- FXX1 FFFF
        u_sim_file : entity work.sim_file
            generic map (
                C_OUTPUT_FILE => G_OUTPUT_FILE)
            port map (
                arst_i => arst_i, clk_i => clk_i,
                xtr_cmd_i => xtr_cmd_lyr_2(1), xtr_rsp_o => xtr_rsp_lyr_2(1));        
    end generate gen_file_output;


    -- 8XX2 0000
    -- FXX2 FFFF
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if xtr_cmd_lyr_2(2).vld = '1' and xtr_cmd_lyr_2(2).we = '1' then
                if xtr_cmd_lyr_2(2).dat = x"CAFECAFE" and xtr_cmd_lyr_2(2).sel = x"F" then
                    assert false report "Finished simulation" severity failure;
                end if;
            end if;
            xtr_rsp_lyr_2(2).vld <= xtr_cmd_lyr_2(2).vld and not xtr_cmd_lyr_2(2).we;
        end if;
    end process;
    xtr_rsp_lyr_2(2).rdy <= '1';
    xtr_rsp_lyr_2(2).dat <= x"DEADBEEF";

    -- Memory delay test logic
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            memory_current_st <= st_idle;
        elsif rising_edge(clk_i) then
            case memory_current_st is
                when st_idle =>
                    if xtr_cmd_lyr_2(3).adr(15) = '1' and xtr_cmd_lyr_2(3).vld = '1' and xtr_cmd_lyr_2(3).we = '0' then
                        memory_current_st <= st_delay_read;
                    elsif xtr_cmd_lyr_2(3).vld = '1' then
                        memory_current_st <= st_delay_cmd;
                    end if;
                when st_delay_cmd | st_delay_read =>
                    if memory_test_delay_cnt(memory_test_delay_cnt'left) = '1' then
                        memory_current_st <= st_idle;
                    end if;
                when others =>
            end case;
        end if;
    end process;
    -- Memory delay test
    -- 8XX3 0000
    -- FXX3 FFFF
    -- Write/Read at 0x80030000 to stimulate not ready command state
    -- Read at 0x80038000 to stimulate delayed read state
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_current_st /= st_idle and memory_test_delay_cnt(memory_test_delay_cnt'left) = '0' then
                memory_test_delay_cnt <= memory_test_delay_cnt + 1;
            else
                memory_test_delay_cnt <= (others => '0');
            end if;
            if xtr_cmd_lyr_2(3).vld = '1' and xtr_cmd_lyr_2(3).we = '1' and xtr_rsp_lyr_2(3).rdy = '1' then
                for i in 0 to 3 loop
                    if xtr_cmd_lyr_2(3).sel(i) = '1' then
                        memory_test_reg(i*8 + 7 downto i*8) <= xtr_cmd_lyr_2(3).dat(i*8 + 7 downto i*8);
                    end if;
                end loop;
            end if;
            if memory_current_st = st_delay_read then
                xtr_rsp_lyr_2(3).vld <= memory_test_delay_cnt(memory_test_delay_cnt'left);
            else
                xtr_rsp_lyr_2(3).vld <= memory_test_delay_cnt(memory_test_delay_cnt'left) and not xtr_cmd_lyr_2(3).we;
            end if;
        end if;
    end process;
    xtr_rsp_lyr_2(3).dat <= memory_test_reg when xtr_rsp_lyr_2(3).vld = '1' else (others => 'X');
    xtr_rsp_lyr_2(3).rdy <= '1' when xtr_cmd_lyr_2(3).adr(15) = '1' and xtr_cmd_lyr_2(3).vld = '1' and xtr_cmd_lyr_2(3).we = '0' and memory_current_st = st_idle else memory_test_delay_cnt(memory_test_delay_cnt'left);
    
    -- External IRQ
    -- 8XX6 0000
    -- 8XX6 FFFF
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            irq_cnt <= (others => '0');
        elsif rising_edge(clk_i) then
            if xtr_cmd_lyr_2(6).vld = '1' then
                irq_cnt <= (others => '0');
            elsif irq_cnt(irq_cnt'left) = '0' then
                irq_cnt <= irq_cnt + 1;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            xtr_rsp_lyr_2(6).vld <= xtr_cmd_lyr_2(6).vld and not xtr_cmd_lyr_2(6).we;
        end if;
    end process;
    xtr_rsp_lyr_2(6).rdy <= '1';
    xtr_rsp_lyr_2(6).dat <= x"DEADBEEF";
    external_irq <= irq_cnt(irq_cnt'left);

    -- MTIME
    -- 8XX7 0000
    -- FXX7 FFFF
    u_xtr_mtime : entity work.xtr_mtime
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => sys_rst,
            xtr_cmd_i => xtr_cmd_lyr_2(7),
            xtr_rsp_o => xtr_rsp_lyr_2(7),
            irq_o => timer_irq
        );

end architecture rtl;