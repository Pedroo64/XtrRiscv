library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity cpu is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_EXECUTE_BYPASS : boolean := FALSE;
        G_MEMORY_BYPASS : boolean := FALSE;
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_ZICSR : boolean := TRUE
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
    constant C_ECALL : boolean := G_ZICSR;
    constant C_EBREAK : boolean := G_ZICSR;
    constant C_INTERRUPTS : boolean := G_ZICSR;
    signal ctl_booted : std_logic;
-- fetch
    signal fetch_en, fetch_flush, fetch_valid, fetch_load_pc : std_logic;
    signal fetch_target_pc, fetch_instr : std_logic_vector(31 downto 0);
-- prefetch
    signal prefetch_en, prefetch_flush, prefetch_valid : std_logic;
    signal prefetch_data : std_logic_vector(31 downto 0);
-- decode
    signal decode_en, decode_flush, decode_valid : std_logic;
    signal decode_opcode : opcode_t;
    signal decode_rs1_adr, decode_rs2_adr, decode_rd_adr : std_logic_vector(4 downto 0);
    signal decode_rd_we : std_logic;
    signal decode_imm, decode_instr : std_logic_vector(31 downto 0);
    signal decode_funct3 : std_logic_vector(2 downto 0);
    signal decode_funct7 : std_logic_vector(6 downto 0);
-- execute
    signal execute_en, execute_flush, execute_valid, execute_ready, execute_multicycle_flush : std_logic;
    signal execute_opcode : opcode_t;
    signal execute_rs1_adr, execute_rs2_adr, execute_rd_adr : std_logic_vector(4 downto 0);
    signal execute_rd_we : std_logic;
    signal execute_pc, execute_rs1_dat, execute_rs2_dat, execute_alu_result_a, execute_alu_result_b, execute_imm : std_logic_vector(31 downto 0);
    signal execute_funct3 : std_logic_vector(2 downto 0);
    signal execute_multicycle : std_logic;
    signal execute_forward_rd_dat : std_logic_vector(31 downto 0);
-- execute-shifter
    signal execute_shifter_result : std_logic_vector(31 downto 0);
-- memory
    signal memory_en, memory_flush, memory_valid, memory_ready, memory_cmd_en : std_logic;
    signal memory_opcode : opcode_t;
    signal memory_rd_adr : std_logic_vector(4 downto 0);
    signal memory_rd_dat : std_logic_vector(31 downto 0);
    signal memory_rd_we : std_logic;
    signal memory_funct3 : std_logic_vector(2 downto 0);
    signal memory_alu_result_a, memory_alu_result_b, memory_forward_rd_dat : std_logic_vector(31 downto 0);
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
-- regfile
    signal regfile_rs1_en, regfile_rs2_en, regfile_rd_we : std_logic;
    signal regfile_rs1_adr, regfile_rs2_adr, regfile_rd_adr : std_logic_vector(4 downto 0);
    signal regfile_rs1_dat, regfile_rs2_dat, regfile_rd_dat : std_logic_vector(31 downto 0);
begin
-- fetch
    fetch_load_pc <= branch_load_pc;
    fetch_target_pc <= branch_target_pc;
    u_fetch : entity work.instruction_fecth
        generic map (
            G_BOOT_ADDRESS => G_BOOT_ADDRESS
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
            valid_o => fetch_valid,
            instr_o => fetch_instr,
            booted_o => ctl_booted
        );
-- prefetch
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            prefetch_valid <= '0';
        elsif rising_edge(clk_i) then
            if prefetch_en = '1' then
                if prefetch_flush = '1' then
                    prefetch_valid <= '0';
                else
                    prefetch_valid <= fetch_en;
                end if;
            end if;
        end if;
    end process;
    prefetch_flush <= decode_flush;
    prefetch_en <= decode_en;
    prefetch_data <= fetch_instr;

-- decode
    u_decode : entity work.instruction_decode
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => decode_flush,
            enable_i => decode_en,
            valid_i => prefetch_valid,
            instr_i => prefetch_data,
            valid_o => decode_valid,
            opcode_o => decode_opcode,
            rs1_adr_o => decode_rs1_adr,
            rs2_adr_o => decode_rs2_adr,
            rd_adr_o => decode_rd_adr,
            rd_we_o => decode_rd_we,
            immediate_o => decode_imm,
            funct3_o => decode_funct3,
            funct7_o => decode_funct7,
            instr_o => decode_instr
        );
-- execute
    u_execute : entity work.execute
        generic map (
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => execute_flush,
            enable_i => execute_en,
            multicycle_flush_i => execute_multicycle_flush,
            valid_i => decode_valid,
            instr_i => decode_instr,
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
            shifter_result_o => execute_shifter_result,
            target_pc_i => branch_target_pc,
            load_pc_i => branch_load_pc,
            current_pc_o => execute_pc,
            multicycle_o => execute_multicycle,
            ready_o => execute_ready
        );
-- memory
    u_memory : entity work.memory
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            flush_i => memory_flush,
            enable_i => memory_en,
            valid_i => execute_valid,
            opcode_i => execute_opcode,
            funct3_i => execute_funct3,
            rd_adr_i => execute_rd_adr,
            rd_we_i => execute_rd_we,
            alu_result_a_i => execute_alu_result_a,
            alu_result_b_i => execute_alu_result_b,
            csr_read_data_i => csr_read_dat,
            valid_o => memory_valid,
            opcode_o => memory_opcode,
            rd_adr_o => memory_rd_adr,
            rd_we_o => memory_rd_we,
            rd_dat_o => memory_rd_dat,
            funct3_o => memory_funct3,
            alu_result_a_o => memory_alu_result_a,
            alu_result_b_o => memory_alu_result_b,
            cmd_en_i => memory_cmd_en,
            cmd_adr_o => data_cmd_adr_o,
            cmd_dat_o => data_cmd_dat_o,
            cmd_vld_o => data_cmd_vld_o,
            cmd_we_o => data_cmd_we_o,
            cmd_siz_o => data_cmd_siz_o,
            cmd_rdy_i => data_cmd_rdy_i,
            ready_o => memory_ready,
            forward_rd_dat_o => execute_forward_rd_dat
        );
-- writeback
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
            valid_o => writeback_valid,
            rd_adr_o => writeback_rd_adr,
            rd_dat_o => writeback_rd_dat,
            rd_we_o => writeback_rd_we,
            ready_o => writeback_ready,
            forward_rd_dat_o => memory_forward_rd_dat
        );
-- control unit
    u_control_unit : entity work.control_unit
        generic map (
            G_EXECUTE_BYPASS => G_EXECUTE_BYPASS,
            G_MEMORY_BYPASS => G_MEMORY_BYPASS,
            G_WRITEBACK_BYPASS => G_WRITEBACK_BYPASS
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            load_pc_i => branch_load_pc,
            decode_valid_i => decode_valid,
            decode_opcode_i => decode_opcode,
            decode_rs1_adr_i => decode_rs1_adr,
            decode_rs2_adr_i => decode_rs2_adr,
            execute_valid_i => execute_valid,
            execute_rd_adr_i => execute_rd_adr,
            execute_rd_we_i => execute_rd_we,
            execute_multicycle_i => execute_multicycle,
            execute_ready_i => execute_ready,
            memory_valid_i => memory_valid,
            memory_rd_adr_i => memory_rd_adr,
            memory_rd_we_i => memory_rd_we,
            memory_ready_i => memory_ready,
            writeback_valid_i => writeback_valid,
            writeback_rd_adr_i => writeback_rd_adr,
            writeback_rd_we_i => writeback_rd_we,
            writeback_ready_i => writeback_ready,
            fetch_flush_o => fetch_flush,
            fetch_enable_o => fetch_en,
            decode_flush_o => decode_flush,
            decode_enable_o => decode_en,
            execute_flush_o => execute_flush,
            execute_enable_o => execute_en,
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
gen_csr: if G_ZICSR = TRUE generate
    u_csr : entity work.csr
        generic map (
            G_ECALL => C_ECALL,
            G_EBREAK => C_EBREAK,
            G_INTERRUPTS => C_INTERRUPTS
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
            memory_funct3_i => memory_funct3,
            memory_target_pc_i => memory_alu_result_b,
            memory_branch_i => branch_branch,
            read_data_o => csr_read_dat,
            target_pc_o => csr_exception_target_pc,
            load_pc_o => csr_exception_load_pc,
            external_interrupt_i => external_irq_i,
            timer_interrupt_i => timer_irq_i
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

end architecture rtl;