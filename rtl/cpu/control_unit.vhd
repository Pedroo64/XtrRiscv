library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity control_unit is
    generic (
        G_EXECUTE_BYPASS : boolean := FALSE;
        G_MEMORY_BYPASS : boolean := FALSE;
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_REGFILE_BYPASS : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        load_pc_i : in std_logic;
        decode_valid_i : in std_logic;
        decode_opcode_i : in opcode_t;
        decode_rs1_adr_i : in std_logic_vector(4 downto 0);
        decode_rs1_en_i : in std_logic;
        decode_rs2_adr_i : in std_logic_vector(4 downto 0);
        decode_rs2_en_i : in std_logic;
        execute_valid_i : in std_logic;
        execute_rd_adr_i : in std_logic_vector(4 downto 0);
        execute_rd_we_i : in std_logic;
        execute_shifter_start_i : in std_logic;
        execute_shifter_ready_i : in std_logic;
        execute_muldiv_start_i : in std_logic;
        execute_muldiv_ready_i : in std_logic;
        execute_multicycle_i : in std_logic;
        memory_valid_i : in std_logic;
        memory_rd_adr_i : in std_logic_vector(4 downto 0);
        memory_rd_we_i : in std_logic;
        memory_ready_i : in std_logic;
        writeback_valid_i : in std_logic;
        writeback_rd_adr_i : in std_logic_vector(4 downto 0);
        writeback_rd_we_i : in std_logic;
        writeback_muldiv_i : in std_logic;
        writeback_ready_i : in std_logic;
        lsu_cmd_rdy_i : in std_logic;
        lsu_rsp_rdy_i : in std_logic;
        fetch_flush_o : out std_logic;
        fetch_enable_o : out std_logic;
        decode_flush_o : out std_logic;
        decode_enable_o : out std_logic;
        execute_flush_o : out std_logic;
        execute_enable_o : out std_logic;
        execute_multicycle_enable_o : out std_logic;
        execute_multicycle_flush_o : out std_logic;
        memory_flush_o : out std_logic;
        memory_enable_o : out std_logic;
        memory_cmd_en_o : out std_logic;
        writeback_flush_o : out std_logic;
        writeback_enable_o : out std_logic;
        execute_opcode_i : in opcode_t;
        memory_opcode_i : in opcode_t;
        execute_rs1_adr_i : in std_logic_vector(4 downto 0);
        execute_rs2_adr_i : in std_logic_vector(4 downto 0);
        regfile_rs1_dat_i : in std_logic_vector(31 downto 0);
        regfile_rs2_dat_i : in std_logic_vector(31 downto 0);
        execute_rd_dat_i : in std_logic_vector(31 downto 0);
        memory_rd_dat_i : in std_logic_vector(31 downto 0);
        writeback_rd_dat_i : in std_logic_vector(31 downto 0);
        decode_rs1_dat_o : out std_logic_vector(31 downto 0);
        decode_rs2_dat_o : out std_logic_vector(31 downto 0)
    );
end entity control_unit;

architecture rtl of control_unit is
    signal decode_use_rs1, decode_use_rs2 : std_logic;
    signal regfile_rd_adr : std_logic_vector(4 downto 0);
    signal regfile_rd_we : std_logic;
    signal regfile_rd_dat : std_logic_vector(31 downto 0);
    signal decode_execute_rs1_hazard, decode_execute_rs2_hazard : std_logic;
    signal decode_memory_rs1_hazard, decode_memory_rs2_hazard : std_logic;
    signal decode_writeback_rs1_hazard, decode_writeback_rs2_hazard : std_logic;
    signal decode_regfile_rs1_hazard, decode_regfile_rs2_hazard : std_logic;
    signal rs1_hazard, rs2_hazard : std_logic;
    signal fetch_stall, decode_stall, execute_stall, memory_stall, writeback_stall : std_logic;
    signal fetch_flush, decode_flush, execute_flush, memory_flush, writeback_flush : std_logic;
    signal decode_execute_opcode_sys_hazard : std_logic;
    signal multicycle_start : std_logic;
    signal shifter_busy : std_logic;
    signal muldiv_busy : std_logic;
    signal lsu_cmd_busy, lsu_rsp_busy : std_logic;
-- Datapath forward
    signal decode_execute_rs1_forward, decode_execute_rs2_forward : std_logic;
    signal decode_memory_rs1_forward, decode_memory_rs2_forward : std_logic;
    signal decode_writeback_rs1_forward, decode_writeback_rs2_forward : std_logic;
    signal decode_regfile_rs1_forward, decode_regfile_rs2_forward : std_logic;
begin
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            regfile_rd_adr <= writeback_rd_adr_i;
            regfile_rd_we <= writeback_rd_we_i;
        end if;
    end process;
-- hazard check
    decode_use_rs1 <= decode_rs1_en_i;
    decode_use_rs2 <= decode_rs2_en_i;

    decode_execute_rs1_hazard <=
        '1' when execute_valid_i = '1' and decode_rs1_adr_i = execute_rd_adr_i and execute_opcode_i.load = '1' and G_EXECUTE_BYPASS = TRUE else
        '1' when execute_rd_we_i = '1' and decode_rs1_adr_i = execute_rd_adr_i and G_EXECUTE_BYPASS = FALSE else
        '0';
    decode_execute_rs2_hazard <=
        '1' when execute_valid_i = '1' and decode_rs2_adr_i = execute_rd_adr_i and execute_opcode_i.load = '1' and G_EXECUTE_BYPASS = TRUE else
        '1' when execute_rd_we_i = '1' and decode_rs2_adr_i = execute_rd_adr_i and G_EXECUTE_BYPASS = FALSE else
        '0';

    decode_memory_rs1_hazard <=
        '1' when memory_valid_i = '1' and decode_rs1_adr_i = memory_rd_adr_i and memory_opcode_i.load = '1' and G_MEMORY_BYPASS = TRUE else
        '1' when memory_rd_we_i = '1' and decode_rs1_adr_i = memory_rd_adr_i and G_MEMORY_BYPASS = FALSE else
        '0';
    decode_memory_rs2_hazard <=
        '1' when memory_valid_i = '1' and decode_rs2_adr_i = memory_rd_adr_i and memory_opcode_i.load = '1' and G_MEMORY_BYPASS = TRUE else
        '1' when memory_rd_we_i = '1' and decode_rs2_adr_i = memory_rd_adr_i and G_MEMORY_BYPASS = FALSE else
        '0';

    decode_writeback_rs1_hazard <=
        '1' when writeback_rd_we_i = '1' and decode_rs1_adr_i = writeback_rd_adr_i and G_WRITEBACK_BYPASS = FALSE else
        '0';
    decode_writeback_rs2_hazard <=
        '1' when writeback_rd_we_i = '1' and decode_rs2_adr_i = writeback_rd_adr_i and G_WRITEBACK_BYPASS = FALSE else
        '0';

    decode_regfile_rs1_hazard <=
        '1' when regfile_rd_we = '1' and decode_rs1_adr_i = regfile_rd_adr and G_REGFILE_BYPASS = FALSE else
        '0';
    decode_regfile_rs2_hazard <=
        '1' when regfile_rd_we = '1' and decode_rs2_adr_i = regfile_rd_adr and G_REGFILE_BYPASS = FALSE else
        '0';

    rs1_hazard <= '1' when decode_use_rs1 = '1' and (decode_execute_rs1_hazard or decode_memory_rs1_hazard or decode_writeback_rs1_hazard or decode_regfile_rs1_hazard) = '1' else '0';
    rs2_hazard <= '1' when decode_use_rs2 = '1' and (decode_execute_rs2_hazard or decode_memory_rs2_hazard or decode_writeback_rs2_hazard or decode_regfile_rs2_hazard) = '1' else '0';

    decode_execute_opcode_sys_hazard <= execute_valid_i and execute_opcode_i.sys;

    multicycle_start <= execute_muldiv_start_i or execute_shifter_start_i;

    shifter_busy <= not execute_shifter_ready_i when G_SHIFTER_EARLY_INJECTION = TRUE else '0';

-- LSU
    lsu_cmd_busy <= not lsu_cmd_rdy_i;
    lsu_rsp_busy <= not lsu_rsp_rdy_i;

-- pipeline ctl
    fetch_stall <= decode_stall;
    decode_stall <= (execute_stall or ((rs1_hazard or rs2_hazard or multicycle_start) or decode_execute_opcode_sys_hazard)) and not load_pc_i;
    execute_stall <= memory_stall or muldiv_busy or shifter_busy or lsu_cmd_busy;
    memory_stall <= not (memory_ready_i) or writeback_stall or lsu_rsp_busy;
    writeback_stall <= not writeback_ready_i;

    fetch_flush <= load_pc_i;
    decode_flush <= load_pc_i;
    execute_flush <= ((rs1_hazard or rs2_hazard or decode_execute_opcode_sys_hazard or multicycle_start)) or load_pc_i;
    memory_flush <= load_pc_i;
    writeback_flush <= memory_stall and writeback_ready_i;

    fetch_flush_o <= srst_i or fetch_flush;
    decode_flush_o <= srst_i or decode_flush;
    execute_flush_o <= srst_i or execute_flush;
    memory_flush_o <= srst_i or memory_flush;
    writeback_flush_o <= srst_i or writeback_flush;

    execute_multicycle_flush_o <= srst_i or load_pc_i;

    fetch_enable_o <= not fetch_stall;
    decode_enable_o <= not decode_stall;
    execute_enable_o <= not execute_stall;
    memory_enable_o <= not memory_stall;
    writeback_enable_o <= not writeback_stall;

    memory_cmd_en_o <= writeback_ready_i;

    execute_multicycle_enable_o <= not memory_stall;

-- Datapath forward
    decode_execute_rs1_forward <=
        '1' when execute_rd_we_i = '1' and decode_rs1_adr_i = execute_rd_adr_i and G_EXECUTE_BYPASS = TRUE else
        '0';
    decode_execute_rs2_forward <=
        '1' when execute_rd_we_i = '1' and decode_rs2_adr_i = execute_rd_adr_i and G_EXECUTE_BYPASS = TRUE else
        '0';

    decode_memory_rs1_forward <=
        '1' when memory_rd_we_i = '1' and decode_rs1_adr_i = memory_rd_adr_i and G_MEMORY_BYPASS = TRUE else
        '0';
    decode_memory_rs2_forward <=
        '1' when memory_rd_we_i = '1' and decode_rs2_adr_i = memory_rd_adr_i and G_MEMORY_BYPASS = TRUE else
        '0';

    decode_writeback_rs1_forward <=
        '1' when writeback_rd_we_i = '1' and decode_rs1_adr_i = writeback_rd_adr_i and G_WRITEBACK_BYPASS = TRUE else
        '0';
    decode_writeback_rs2_forward <=
        '1' when writeback_rd_we_i = '1' and decode_rs2_adr_i = writeback_rd_adr_i and G_WRITEBACK_BYPASS = TRUE else
        '0';

    decode_regfile_rs1_forward <=
        '1' when regfile_rd_we = '1' and decode_rs1_adr_i = regfile_rd_adr and G_REGFILE_BYPASS = TRUE else
        '0';
    decode_regfile_rs2_forward <=
        '1' when regfile_rd_we = '1' and decode_rs2_adr_i = regfile_rd_adr and G_REGFILE_BYPASS = TRUE else
        '0';

    gen_regfile_datapayth_bypass: if G_REGFILE_BYPASS = TRUE generate
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                regfile_rd_dat <= writeback_rd_dat_i;
            end if;
        end process;
    end generate gen_regfile_datapayth_bypass;

    decode_rs1_dat_o <=
        execute_rd_dat_i when decode_execute_rs1_forward = '1' else
        memory_rd_dat_i when decode_memory_rs1_forward = '1' else
        writeback_rd_dat_i when decode_writeback_rs1_forward = '1' else
        regfile_rd_dat when decode_regfile_rs1_forward = '1' else
        regfile_rs1_dat_i;

    decode_rs2_dat_o <=
        execute_rd_dat_i when decode_execute_rs2_forward = '1' else
        memory_rd_dat_i when decode_memory_rs2_forward = '1' else
        writeback_rd_dat_i when decode_writeback_rs2_forward = '1' else
        regfile_rd_dat when decode_regfile_rs2_forward = '1' else
        regfile_rs2_dat_i;

-- muldiv
gen_muldiv_ctl: if G_EXTENSION_M = TRUE generate
    signal nxt_muldiv_busy : std_logic;
begin
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            muldiv_busy <= '0';
        elsif rising_edge(clk_i) then
            muldiv_busy <= nxt_muldiv_busy;
        end if;
    end process;
    nxt_muldiv_busy <=
        '1' when muldiv_busy = '0' and execute_muldiv_start_i = '1' and load_pc_i = '0' else
        '0' when muldiv_busy = '1' and (writeback_valid_i and writeback_muldiv_i and execute_muldiv_ready_i) = '1' else
        muldiv_busy;
end generate gen_muldiv_ctl;
gen_no_muldiv: if G_EXTENSION_M = FALSE generate
    muldiv_busy <= '0';
end generate gen_no_muldiv;

end architecture rtl;