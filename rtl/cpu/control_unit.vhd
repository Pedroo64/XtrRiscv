library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity control_unit is
    generic (
        G_EXECUTE_BYPASS : boolean := FALSE;
        G_MEMORY_BYPASS : boolean := FALSE;
        G_WRITEBACK_BYPASS : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        load_pc_i : in std_logic;
        decode_valid_i : in std_logic;
        decode_opcode_i : in opcode_t;
        decode_rs1_adr_i : in std_logic_vector(4 downto 0);
        decode_rs2_adr_i : in std_logic_vector(4 downto 0);
        execute_valid_i : in std_logic;
        execute_rd_adr_i : in std_logic_vector(4 downto 0);
        execute_rd_we_i : in std_logic;
        execute_ready_i : in std_logic;
        execute_multicycle_i : in std_logic;
        memory_valid_i : in std_logic;
        memory_rd_adr_i : in std_logic_vector(4 downto 0);
        memory_rd_we_i : in std_logic;
        memory_ready_i : in std_logic;
        writeback_valid_i : in std_logic;
        writeback_rd_adr_i : in std_logic_vector(4 downto 0);
        writeback_rd_we_i : in std_logic;
        writeback_ready_i : in std_logic;
        fetch_flush_o : out std_logic;
        fetch_enable_o : out std_logic;
        decode_flush_o : out std_logic;
        decode_enable_o : out std_logic;
        execute_flush_o : out std_logic;
        execute_enable_o : out std_logic;
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
        execute_rd_adr_forward_i : in std_logic_vector(4 downto 0);
        execute_rd_dat_forward_i : in std_logic_vector(31 downto 0);
        execute_rd_we_forward_i : in std_logic;
        memory_rd_adr_forward_i : in std_logic_vector(4 downto 0);
        memory_rd_dat_forward_i : in std_logic_vector(31 downto 0);
        memory_rd_we_forward_i : in std_logic;
        writeback_rd_dat_i : in std_logic_vector(31 downto 0);
        execute_rs1_dat_o : out std_logic_vector(31 downto 0);
        execute_rs2_dat_o : out std_logic_vector(31 downto 0)
    );
end entity control_unit;

architecture rtl of control_unit is
    signal decode_use_rs1, decode_use_rs2 : std_logic;
    signal decode_rs1_zero, decode_rs2_zero : std_logic;
    signal decode_execute_rs1_hazard, decode_execute_rs2_hazard : std_logic;
    signal decode_memory_rs1_hazard, decode_memory_rs2_hazard : std_logic;
    signal decode_writeback_rs1_hazard, decode_writeback_rs2_hazard : std_logic;
    signal rs1_hazard, rs2_hazard : std_logic;
    signal fetch_stall, decode_stall, execute_stall, memory_stall, writeback_stall : std_logic;
    signal fetch_flush, decode_flush, execute_flush, memory_flush, writeback_flush : std_logic;
-- Datapath forward
    signal writeback_rd_adr_forward : std_logic_vector(4 downto 0);
    signal writeback_rd_dat_forward : std_logic_vector(31 downto 0);
    signal writeback_rd_we_forward : std_logic := '0';
    signal execute_use_rs1, execute_use_rs2 : std_logic := '0';
    signal rs1_execute_forward, rs1_memory_forward, rs1_writeback_forward : std_logic := '0';
    signal rs2_execute_forward, rs2_memory_forward, rs2_writeback_forward : std_logic := '0';
begin
-- hazard check
    decode_use_rs1 <= decode_opcode_i.reg_reg or decode_opcode_i.load or decode_opcode_i.reg_imm or decode_opcode_i.jalr or decode_opcode_i.store or decode_opcode_i.branch or decode_opcode_i.sys;
    decode_use_rs2 <= decode_opcode_i.reg_reg or decode_opcode_i.store or decode_opcode_i.branch;

    decode_rs1_zero <= '1' when unsigned(decode_rs1_adr_i) = 0 else '0';
    decode_rs2_zero <= '1' when unsigned(decode_rs2_adr_i) = 0 else '0';

    decode_execute_rs1_hazard <= 
        (execute_valid_i) when decode_rs1_adr_i = execute_rd_adr_i and execute_opcode_i.load = '1' and G_EXECUTE_BYPASS = TRUE else 
        (execute_rd_we_i) when decode_rs1_adr_i = execute_rd_adr_i and G_EXECUTE_BYPASS = FALSE else 
        '0';
    decode_execute_rs2_hazard <= 
        (execute_valid_i) when decode_rs2_adr_i = execute_rd_adr_i and execute_opcode_i.load = '1' and G_EXECUTE_BYPASS = TRUE else 
        (execute_rd_we_i) when decode_rs2_adr_i = execute_rd_adr_i and G_EXECUTE_BYPASS = FALSE else 
        '0';

    decode_memory_rs1_hazard <= 
        (memory_valid_i) when decode_rs1_adr_i = memory_rd_adr_i and memory_opcode_i.load = '1' and G_MEMORY_BYPASS = TRUE else 
        (memory_rd_we_i) when decode_rs1_adr_i = memory_rd_adr_i and G_MEMORY_BYPASS = FALSE else 
        '0';
    decode_memory_rs2_hazard <= 
        (memory_valid_i) when decode_rs2_adr_i = memory_rd_adr_i and memory_opcode_i.load = '1' and G_MEMORY_BYPASS = TRUE else 
        (memory_rd_we_i) when decode_rs2_adr_i = memory_rd_adr_i and G_MEMORY_BYPASS = FALSE else 
        '0';

    decode_writeback_rs1_hazard <= 
        (writeback_rd_we_i) when decode_rs1_adr_i = writeback_rd_adr_i and G_WRITEBACK_BYPASS = FALSE else 
        '0';
    decode_writeback_rs2_hazard <= 
        (writeback_rd_we_i) when decode_rs2_adr_i = writeback_rd_adr_i and G_WRITEBACK_BYPASS = FALSE else 
        '0';

    rs1_hazard <= decode_use_rs1 when decode_rs1_zero = '0' and (decode_execute_rs1_hazard or decode_memory_rs1_hazard or decode_writeback_rs1_hazard) = '1' else '0';
    rs2_hazard <= decode_use_rs2 when decode_rs2_zero = '0' and (decode_execute_rs2_hazard or decode_memory_rs2_hazard or decode_writeback_rs2_hazard) = '1' else '0';

-- pipeline ctl
    fetch_stall <= decode_stall and not load_pc_i;
    decode_stall <= (execute_stall or ((rs1_hazard or rs2_hazard or execute_multicycle_i))) and not load_pc_i;
    execute_stall <= memory_stall;
    memory_stall <= not (memory_ready_i and execute_ready_i) or writeback_stall;
    writeback_stall <= not writeback_ready_i;

    fetch_flush <= load_pc_i;
    decode_flush <= load_pc_i;
    execute_flush <= ((rs1_hazard or rs2_hazard)) or load_pc_i or execute_multicycle_i;
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

-- Datapath forward
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if execute_stall = '0' then
                execute_use_rs1 <= decode_use_rs1 and not decode_rs1_zero;
                execute_use_rs2 <= decode_use_rs2 and not decode_rs2_zero;
            end if;
        end if;
    end process;

    rs1_execute_forward <= execute_rd_we_forward_i when execute_rs1_adr_i = execute_rd_adr_forward_i and execute_use_rs1 = '1' and G_EXECUTE_BYPASS = TRUE else '0';
    rs2_execute_forward <= execute_rd_we_forward_i when execute_rs2_adr_i = execute_rd_adr_forward_i and execute_use_rs2 = '1' and G_EXECUTE_BYPASS = TRUE else '0';
    
    rs1_memory_forward <= memory_rd_we_forward_i when execute_rs1_adr_i = memory_rd_adr_forward_i and execute_use_rs1 = '1' and G_MEMORY_BYPASS = TRUE else '0';
    rs2_memory_forward <= memory_rd_we_forward_i when execute_rs2_adr_i = memory_rd_adr_forward_i and execute_use_rs2 = '1' and G_MEMORY_BYPASS = TRUE else '0';
    
    rs1_writeback_forward <= writeback_rd_we_forward when execute_rs1_adr_i = writeback_rd_adr_forward and execute_use_rs1 = '1' and G_WRITEBACK_BYPASS = TRUE else '0';
    rs2_writeback_forward <= writeback_rd_we_forward when execute_rs2_adr_i = writeback_rd_adr_forward and execute_use_rs2 = '1' and G_WRITEBACK_BYPASS = TRUE else '0';

    execute_rs1_dat_o <= 
        execute_rd_dat_forward_i when rs1_execute_forward = '1' else
        memory_rd_dat_forward_i when rs1_memory_forward = '1' else
        writeback_rd_dat_forward when rs1_writeback_forward = '1' else
        regfile_rs1_dat_i;

    execute_rs2_dat_o <= 
        execute_rd_dat_forward_i when rs2_execute_forward = '1' else
        memory_rd_dat_forward_i when rs2_memory_forward = '1' else
        writeback_rd_dat_forward when rs2_writeback_forward = '1' else
        regfile_rs2_dat_i;

gen_writeback_bypass: if G_WRITEBACK_BYPASS = TRUE generate
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            writeback_rd_adr_forward <= writeback_rd_adr_i;
            writeback_rd_dat_forward <= writeback_rd_dat_i;
            writeback_rd_we_forward <= writeback_rd_we_i;
        end if;
    end process;
end generate gen_writeback_bypass;
end architecture rtl;