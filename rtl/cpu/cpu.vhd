library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;
use work.vhdl_utils.all;

entity cpu is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_PREFETCH_SIZE : integer := 16;
        G_EXECUTE_BYPASS : boolean := FALSE;
        G_MEMORY_BYPASS : boolean := FALSE;
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE;
        G_EXTENSION_C : boolean := FALSE;
        G_EXTENSION_ZICSR : boolean := FALSE;
        G_VERIFICATION : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        instr_cmd_adr_o : out std_logic_vector(31 downto 0);
        instr_cmd_vld_o : out std_logic;
        instr_cmd_rdy_i : in std_logic;
        instr_rsp_dat_i : in std_logic_vector(31 downto 0);
        instr_rsp_vld_i : in std_logic;
        data_cmd_adr_o : out std_logic_vector(31 downto 0);
        data_cmd_vld_o : out std_logic;
        data_cmd_we_o : out std_logic;
        data_cmd_siz_o : out std_logic_vector(1 downto 0);
        data_cmd_rdy_i : in std_logic;
        data_cmd_dat_o : out std_logic_vector(31 downto 0);
        data_rsp_dat_i : in std_logic_vector(31 downto 0);
        data_rsp_vld_i : in std_logic;
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic
    );
end entity cpu;

architecture rtl of cpu is
    constant C_ECALL : boolean := G_EXTENSION_ZICSR;
    constant C_EBREAK : boolean := G_EXTENSION_ZICSR;
    constant C_INTERRUPTS : boolean := G_EXTENSION_ZICSR;
    signal ctl_booted : std_logic;
-- fetch
    signal fetch_en, fetch_flush, fetch_instr_valid, fetch_load_pc, fetch_instr_compressed : std_logic;
    signal fetch_target_pc, fetch_instr_data : std_logic_vector(31 downto 0);
-- decode
    signal decode_en, decode_flush, decode_valid, decode_instr_compressed : std_logic;
    signal decode_opcode : opcode_t;
    signal decode_opcode_type : opcode_type_t;
    signal decode_rs1_adr, decode_rs2_adr, decode_rd_adr : std_logic_vector(4 downto 0);
    signal decode_rs1_en, decode_rs2_en, decode_rd_we : std_logic;
    signal decode_imm, decode_instr : std_logic_vector(31 downto 0);
    signal decode_funct3 : std_logic_vector(2 downto 0);
    signal decode_funct7 : std_logic_vector(6 downto 0);
    signal decode_ctrl : execute_ctrl_t;
-- execute
    signal execute_en, execute_flush, execute_valid, execute_multicycle_enable, execute_multicycle_flush : std_logic;
    signal execute_opcode : opcode_t;
    signal execute_rs1_adr, execute_rs2_adr, execute_rd_adr : std_logic_vector(4 downto 0);
    signal execute_rd_we : std_logic;
    signal execute_pc, execute_rs1_dat, execute_rs2_dat, execute_alu_result_a, execute_alu_result_b, execute_imm : std_logic_vector(31 downto 0);
    signal execute_funct3 : std_logic_vector(2 downto 0);
    signal execute_funct7 : std_logic_vector(6 downto 0);
    signal execute_multicycle : std_logic;
-- execute-shifter
    signal execute_shifter_result : std_logic_vector(31 downto 0);
    signal execute_shifter_start, execute_shifter_ready : std_logic;
-- muldiv
    signal memory_muldiv, writeback_muldiv : std_logic;
    signal execute_muldiv_result : std_logic_vector(31 downto 0);
    signal execute_muldiv_start, execute_muldiv_ready : std_logic;
-- memory
    signal memory_en, memory_flush, memory_valid, memory_ready, memory_cmd_en : std_logic;
    signal memory_opcode : opcode_t;
    signal memory_rd_adr : std_logic_vector(4 downto 0);
    signal memory_rd_dat : std_logic_vector(31 downto 0);
    signal memory_rd_we : std_logic;
    signal memory_funct3 : std_logic_vector(2 downto 0);
    signal memory_funct7 : std_logic_vector(6 downto 0);
    signal memory_alu_result_a, memory_alu_result_b : std_logic_vector(31 downto 0);
-- writeback
    signal writeback_en, writeback_flush, writeback_valid, writeback_ready : std_logic;
    signal writeback_rd_adr : std_logic_vector(4 downto 0);
    signal writeback_rd_dat : std_logic_vector(31 downto 0);
    signal writeback_rd_we : std_logic;
-- branch unit
    signal branch_load_pc, branch_branch : std_logic;
    signal branch_target_pc : std_logic_vector(31 downto 0);
-- csr
    signal csr_exception_target_pc : std_logic_vector(31 downto 0) := (others => '-');
    signal csr_exception_load_pc : std_logic := '0';
    signal csr_read_dat : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_exception_entry, csr_exception_exit, csr_exception_async, csr_exception_sync : std_logic := '0';
    signal csr_mtvec, csr_mepc : std_logic_vector(31 downto 0) := (others => '-');
-- regfile
    signal regfile_rs1_en, regfile_rs2_en, regfile_rd_we : std_logic;
    signal regfile_rs1_adr, regfile_rs2_adr, regfile_rd_adr : std_logic_vector(4 downto 0);
    signal regfile_rs1_dat, regfile_rs2_dat, regfile_rd_dat : std_logic_vector(31 downto 0);
-- memory interface
    signal mem_cmd_adr, mem_cmd_dat : std_logic_vector(31 downto 0);
    signal mem_cmd_siz : std_logic_vector(1 downto 0);
    signal mem_cmd_vld, mem_cmd_we : std_logic;
begin

-- fetch
    fetch_load_pc <= branch_load_pc;
    fetch_target_pc <= branch_target_pc;
    u_fetch : entity work.instruction_fetch
        generic map (
            G_BOOT_ADDRESS => G_BOOT_ADDRESS,
            G_PREFETCH_SIZE => G_PREFETCH_SIZE,
            G_EXTENSION_C => G_EXTENSION_C
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            flush_i => fetch_flush,
            enable_i => fetch_en,
            load_pc_i => fetch_load_pc,
            target_pc_i => fetch_target_pc,
            cmd_adr_o => instr_cmd_adr_o,
            cmd_vld_o => instr_cmd_vld_o,
            cmd_rdy_i => instr_cmd_rdy_i,
            rsp_dat_i => instr_rsp_dat_i,
            rsp_vld_i => instr_rsp_vld_i,
            instr_valid_o => fetch_instr_valid,
            instr_data_o => fetch_instr_data,
            instr_compressed_o => fetch_instr_compressed,
            booted_o => ctl_booted,
            prefetch_full_o => open
        );

-- decode
    u_decode : entity work.instruction_decode
        generic map (
            G_EXTENSION_C => G_EXTENSION_C,
            G_EXTENSION_M => G_EXTENSION_M,
            G_SHIFTER_EARLY_INJECTION => G_SHIFTER_EARLY_INJECTION
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => decode_flush,
            enable_i => decode_en,
            valid_i => fetch_instr_valid,
            instr_i => fetch_instr_data,
            compressed_i => fetch_instr_compressed,
            valid_o => decode_valid,
            opcode_o => decode_opcode,
            opcode_type_o => decode_opcode_type,
            rs1_adr_o => decode_rs1_adr,
            rs1_en_o => decode_rs1_en,
            rs2_adr_o => decode_rs2_adr,
            rs2_en_o => decode_rs2_en,
            rd_adr_o => decode_rd_adr,
            rd_we_o => decode_rd_we,
            immediate_o => decode_imm,
            funct3_o => decode_funct3,
            funct7_o => decode_funct7,
            compressed_o => decode_instr_compressed,
            instr_o => decode_instr,
            ctrl_o => decode_ctrl
        );
-- execute
    u_execute : entity work.execute
        generic map (
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER,
            G_SHIFTER_EARLY_INJECTION => G_SHIFTER_EARLY_INJECTION,
            G_MULDIV => G_EXTENSION_M
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => execute_flush,
            enable_i => execute_en,
            multicycle_enable_i => execute_multicycle_enable,
            multicycle_flush_i => execute_multicycle_flush,
            valid_i => decode_valid,
            instr_i => decode_instr,
            ctrl_i => decode_ctrl,
            compressed_i => decode_instr_compressed,
            opcode_i => decode_opcode,
            rs1_adr_i => decode_rs1_adr,
            rs2_adr_i => decode_rs2_adr,
            rd_adr_i => decode_rd_adr,
            rd_we_i => decode_rd_we,
            immediate_i => decode_imm,
            funct3_i => decode_funct3,
            funct7_i => decode_funct7,
            rs1_dat_i => execute_rs1_dat,
            rs2_dat_i => execute_rs2_dat,
            valid_o => execute_valid,
            opcode_o => execute_opcode,
            rd_adr_o => execute_rd_adr,
            rd_we_o => execute_rd_we,
            immediate_o => execute_imm,
            rs1_adr_o => execute_rs1_adr,
            rs2_adr_o => execute_rs2_adr,
            alu_result_a_o => execute_alu_result_a,
            alu_result_b_o => execute_alu_result_b,
            funct3_o => execute_funct3,
            funct7_o => execute_funct7,
            target_pc_i => branch_target_pc,
            load_pc_i => branch_load_pc,
            current_pc_o => execute_pc,
            multicycle_o => execute_multicycle,
            shifter_start_o => execute_shifter_start,
            shifter_result_o => execute_shifter_result,
            shifter_ready_o => execute_shifter_ready,
            muldiv_start_o => execute_muldiv_start,
            muldiv_result_o => execute_muldiv_result,
            muldiv_ready_o => execute_muldiv_ready
        );
-- memory
    u_memory : entity work.memory
        generic map (
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER,
            G_SHIFTER_EARLY_INJECTION => G_SHIFTER_EARLY_INJECTION
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => memory_flush,
            enable_i => memory_en,
            valid_i => execute_valid,
            opcode_i => execute_opcode,
            funct3_i => execute_funct3,
            funct7_i => execute_funct7,
            rd_adr_i => execute_rd_adr,
            rd_we_i => execute_rd_we,
            alu_result_a_i => execute_alu_result_a,
            alu_result_b_i => execute_alu_result_b,
            shifter_result_i => execute_shifter_result,
            shifter_ready_i => execute_shifter_ready,
            csr_read_data_i => csr_read_dat,
            valid_o => memory_valid,
            opcode_o => memory_opcode,
            rd_adr_o => memory_rd_adr,
            rd_we_o => memory_rd_we,
            rd_dat_o => memory_rd_dat,
            funct3_o => memory_funct3,
            funct7_o => memory_funct7,
            alu_result_a_o => memory_alu_result_a,
            alu_result_b_o => memory_alu_result_b,
            cmd_en_i => memory_cmd_en,
            cmd_adr_o => mem_cmd_adr,
            cmd_dat_o => mem_cmd_dat,
            cmd_vld_o => mem_cmd_vld,
            cmd_we_o => mem_cmd_we,
            cmd_siz_o => mem_cmd_siz,
            cmd_rdy_i => data_cmd_rdy_i,
            ready_o => memory_ready
        );
    data_cmd_adr_o <= mem_cmd_adr;
    data_cmd_dat_o <= mem_cmd_dat;
    data_cmd_vld_o <= mem_cmd_vld;
    data_cmd_we_o <= mem_cmd_we;
    data_cmd_siz_o <= mem_cmd_siz;
-- writeback
    memory_muldiv <= memory_opcode.reg_reg and memory_funct7(0) when G_EXTENSION_M = TRUE else '0';

    u_writeback : entity work.writeback
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => writeback_flush,
            enable_i => writeback_en,
            valid_i => memory_valid,
            memory_read_i => memory_opcode.load,
            funct3_i => memory_funct3,
            rd_adr_i => memory_rd_adr,
            rd_dat_i => memory_rd_dat,
            rd_we_i => memory_rd_we,
            rsp_dat_i => data_rsp_dat_i,
            rsp_vld_i => data_rsp_vld_i,
            muldiv_i => memory_muldiv,
            muldiv_result_i => execute_muldiv_result,
            muldiv_ready_i => execute_muldiv_ready,
            valid_o => writeback_valid,
            rd_adr_o => writeback_rd_adr,
            rd_dat_o => writeback_rd_dat,
            rd_we_o => writeback_rd_we,
            ready_o => writeback_ready,
            muldiv_o => writeback_muldiv
        );
-- control unit
    u_control_unit : entity work.control_unit
        generic map (
            G_EXECUTE_BYPASS => G_EXECUTE_BYPASS,
            G_MEMORY_BYPASS => G_MEMORY_BYPASS,
            G_WRITEBACK_BYPASS => G_WRITEBACK_BYPASS,
            G_EXTENSION_M => G_EXTENSION_M,
            G_SHIFTER_EARLY_INJECTION => G_SHIFTER_EARLY_INJECTION
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            load_pc_i => branch_load_pc,
            decode_valid_i => decode_valid,
            decode_opcode_i => decode_opcode,
            decode_opcode_type_i => decode_opcode_type,
            decode_rs1_adr_i => decode_rs1_adr,
            decode_rs1_en_i => decode_rs1_en,
            decode_rs2_adr_i => decode_rs2_adr,
            decode_rs2_en_i => decode_rs2_en,
            execute_valid_i => execute_valid,
            execute_rd_adr_i => execute_rd_adr,
            execute_rd_we_i => execute_rd_we,
            execute_multicycle_i => execute_multicycle,
            execute_shifter_start_i => execute_shifter_start,
            execute_shifter_ready_i => execute_shifter_ready,
            execute_muldiv_start_i => execute_muldiv_start,
            execute_muldiv_ready_i => execute_muldiv_ready,
            memory_valid_i => memory_valid,
            memory_rd_adr_i => memory_rd_adr,
            memory_rd_we_i => memory_rd_we,
            memory_ready_i => memory_ready,
            writeback_valid_i => writeback_valid,
            writeback_rd_adr_i => writeback_rd_adr,
            writeback_rd_we_i => writeback_rd_we,
            writeback_ready_i => writeback_ready,
            writeback_muldiv_i => writeback_muldiv,
            fetch_flush_o => fetch_flush,
            fetch_enable_o => fetch_en,
            decode_flush_o => decode_flush,
            decode_enable_o => decode_en,
            execute_flush_o => execute_flush,
            execute_enable_o => execute_en,
            execute_multicycle_enable_o => execute_multicycle_enable,
            execute_multicycle_flush_o => execute_multicycle_flush,
            memory_flush_o => memory_flush,
            memory_enable_o => memory_en,
            memory_cmd_en_o => memory_cmd_en,
            writeback_flush_o => writeback_flush,
            writeback_enable_o => writeback_en,
            execute_opcode_i => execute_opcode,
            memory_opcode_i => memory_opcode,
            execute_rs1_adr_i => execute_rs1_adr,
            execute_rs2_adr_i => execute_rs2_adr,
            regfile_rs1_dat_i => regfile_rs1_dat,
            regfile_rs2_dat_i => regfile_rs2_dat,
            execute_rd_dat_i => execute_alu_result_a,
            memory_rd_dat_i => memory_rd_dat,
            writeback_rd_dat_i => writeback_rd_dat,
            execute_rs1_dat_o => execute_rs1_dat,
            execute_rs2_dat_o => execute_rs2_dat
        );

-- branch unit
    u_branch_unit : entity work.branch_unit
        generic map (
            G_BOOT_ADDRESS => G_BOOT_ADDRESS
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            booted_i => ctl_booted,
            execute_rs1_dat_i => execute_rs1_dat,
            execute_rs2_dat_i => execute_rs2_dat,
            execute_funct3_i => execute_funct3,
            memory_valid_i => memory_valid,
            memory_enable_i => memory_en,
            memory_opcode_i => memory_opcode,
            memory_funct3_i => memory_funct3,
            memory_target_pc_i => memory_alu_result_b,
            exception_target_pc_i => csr_exception_target_pc,
            exception_load_pc_i => csr_exception_load_pc,
            target_pc_o => branch_target_pc,
            load_pc_o => branch_load_pc,
            branch_o => branch_branch
        );

-- csr
gen_csr: if G_EXTENSION_ZICSR = TRUE generate
    u_csr : entity work.csr
        generic map (
            G_ECALL => C_ECALL,
            G_EBREAK => C_EBREAK,
            G_INTERRUPTS => C_INTERRUPTS,
            G_EXTENSION_C => G_EXTENSION_C
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            execute_en_i => execute_en,
            execute_valid_i => execute_valid,
            execute_opcode_i => execute_opcode,
            execute_immediate_i => execute_imm,
            execute_funct3_i => execute_funct3,
            execute_current_pc_i => execute_pc,
            execute_rs1_dat_i => execute_rs1_dat,
            execute_zimm_i => execute_rs1_adr,
            memory_en_i => memory_en,
            memory_valid_i => memory_valid,
            memory_opcode_i => memory_opcode,
            memory_address_i => memory_alu_result_a,
            memory_funct3_i => memory_funct3,
            memory_target_pc_i => memory_alu_result_b,
            memory_branch_i => branch_branch,
            read_data_o => csr_read_dat,
            target_pc_o => csr_exception_target_pc,
            load_pc_o => csr_exception_load_pc,
            external_interrupt_i => external_irq_i,
            timer_interrupt_i => timer_irq_i,
            exception_entry_o => csr_exception_entry,
            exception_exit_o => csr_exception_exit,
            exception_sync_o => csr_exception_sync,
            exception_async_o => csr_exception_async,
            mtvec_o => csr_mtvec,
            mepc_o => csr_mepc
        );
end generate gen_csr;

-- regfile
    regfile_rs1_en <= execute_en;
    regfile_rs1_adr <= decode_rs1_adr;
    regfile_rs2_en <= execute_en;
    regfile_rs2_adr <= decode_rs2_adr;
    regfile_rd_adr <= writeback_rd_adr;
    regfile_rd_we <= writeback_rd_we and writeback_en;
    regfile_rd_dat <= writeback_rd_dat;
    u_regfile : entity work.regfile
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            rs1_en_i => regfile_rs1_en,
            rs1_adr_i => regfile_rs1_adr,
            rs1_dat_o => regfile_rs1_dat,
            rs2_en_i => regfile_rs2_en,
            rs2_adr_i => regfile_rs2_adr,
            rs2_dat_o => regfile_rs2_dat,
            rd_adr_i => regfile_rd_adr,
            rd_we_i => regfile_rd_we,
            rd_dat_i => regfile_rd_dat
        );

gen_verif: if G_VERIFICATION = TRUE generate
    u_cpu_checker : entity work.cpu_checker
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            decode_valid_i => decode_valid,
            decode_opcode_i => decode_instr(6 downto 0),
            decode_funct3_i => decode_funct3,
            decode_funct7_i => decode_funct7,
            decode_immediate_i => decode_imm,
            decode_rs1_dat_i => execute_rs1_dat,
            decode_rs2_dat_i => execute_rs2_dat,
            decode_rd_adr_i => decode_rd_adr,
            decode_rd_we_i => decode_rd_we,
            decode_compressed_i => decode_instr_compressed,
            execute_enable_i => execute_en,
            execute_flush_i => execute_flush,
            execute_current_pc_i => execute_pc,
            memory_enable_i => memory_en,
            memory_flush_i => memory_flush,
            memory_mem_cmd_adr_i => mem_cmd_adr,
            memory_mem_cmd_dat_i => mem_cmd_dat,
            memory_mem_cmd_vld_i => mem_cmd_vld,
            memory_mem_cmd_we_i => mem_cmd_we,
            writeback_enable_i => writeback_en,
            writeback_flush_i => writeback_flush,
            writeback_mem_rsp_dat_i => data_rsp_dat_i,
            writeback_mem_rsp_vld_i => data_rsp_vld_i,
            fetch_load_pc_i => fetch_load_pc,
            fetch_target_pc_i => fetch_target_pc,
            csr_exception_entry_i => csr_exception_entry,
            csr_exception_exit_i => csr_exception_exit,
            csr_exception_async_i => csr_exception_async,
            csr_exception_sync_i => csr_exception_sync,
            csr_mtvec_i => csr_mtvec,
            csr_mepc_i => csr_mepc,
            regfile_rd_we_i => regfile_rd_we,
            regfile_rd_dat_i => regfile_rd_dat,
            regfile_rd_adr_i => regfile_rd_adr
        );

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            vhdl_assert(G_EXTENSION_C = TRUE and fetch_instr_valid = '1' and fetch_instr_compressed = '1' and not (fetch_instr_data(1 downto 0) /= "11"), "Expected compressed instruction");
            vhdl_assert(G_EXTENSION_C = TRUE and fetch_instr_valid = '1' and fetch_instr_compressed = '0' and not (fetch_instr_data(1 downto 0) = "11"), "Expected non compressed instruction");
            vhdl_assert(decode_valid = '1' and not (or_reduct(decode_instr) /= 'X'), "Illegal instruction");
        end if;
    end process;
end generate gen_verif;

end architecture rtl;