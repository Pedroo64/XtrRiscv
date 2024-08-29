library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use work.rv32i_pkg.all;
use work.vhdl_utils.all;
use work.csr_def.all;

entity cpu is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_EXECUTE_BYPASS : boolean := TRUE;
        G_MEMORY_BYPASS : boolean := TRUE;
        G_WRITEBACK_BYPASS : boolean := TRUE;
        G_REGFILE_BYPASS : boolean := TRUE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE;
        G_EXTENSION_C : boolean := FALSE;
        G_EXTENSION_ZICSR : boolean := FALSE;
        G_DEBUG_MODULE : boolean := FALSE;
        G_FAST_MUL : boolean := FALSE;
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
        debug_cmd_adr_i : in std_logic_vector(7 downto 0);
        debug_cmd_dat_i : in std_logic_vector(31 downto 0);
        debug_cmd_vld_i : in std_logic;
        debug_cmd_we_i : in std_logic;
        debug_cmd_rdy_o : out std_logic;
        debug_rsp_vld_o : out std_logic;
        debug_rsp_dat_o : out std_logic_vector(31 downto 0);
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic
    );
end entity cpu;

architecture rtl of cpu is
    constant C_CATCH_ILLEGAL : boolean := FALSE and G_EXTENSION_ZICSR;
    constant C_CATCH_MISALIGNED_INSTRUCTION : boolean := FALSE and G_EXTENSION_ZICSR;
    constant C_CATCH_MISALIGNED_LOAD_STORE : boolean := FALSE and G_EXTENSION_ZICSR;
    constant C_IMPL_ECALL : boolean := TRUE and G_EXTENSION_ZICSR;
    constant C_IMPL_EBREAK : boolean := TRUE and G_EXTENSION_ZICSR;
    constant C_TWO_CYCLES_READ : boolean := FALSE;
    constant C_FETCH_FIFO_DEPTH : integer := 1;
    constant C_FETCH_CNT_WIDTH : integer := integer(ceil(log2(real(C_FETCH_FIFO_DEPTH))));
    -- global
    signal booted_q : std_logic;
    signal instr_cmd_rdy, instr_rsp_vld : std_logic;
    signal instr_rsp_dat : std_logic_vector(31 downto 0);
    -- fetch
    signal fetch_enable, fetch_flush, fetch_pc_en, fetch_load_pc_en, fetch_stall, fetch_flush_q : std_logic;
    signal fetch_pc_q, fetch_nxt_pc, fetch_target_pc : std_logic_vector(31 downto 0);
    signal fetch_instr_cmd_vld, fetch_instr_raw_vld : std_logic;
    signal fetch_instr_raw_dat : std_logic_vector(31 downto 0);
    signal fetch_instr_dat_align, fetch_instr_dat : std_logic_vector(31 downto 0);
    signal fetch_instr_vld_align, fetch_instr_vld : std_logic;
    signal fetch_rs1_adr, fetch_rs2_adr : std_logic_vector(4 downto 0);
    signal fetch_instr_rvc : std_logic;
    signal fetch_fifo_clr : std_logic;
    signal fetch_fifo_wdat, fetch_fifo_rdat : std_logic_vector(31 downto 0);
    signal fetch_fifo_we, fetch_fifo_re : std_logic;
    signal fetch_fifo_ef, fetch_fifo_ff : std_logic;
    signal fetch_command_cnt_q, fetch_pending_cnt_q : unsigned(C_FETCH_CNT_WIDTH downto 0);
    signal fetch_pending_inc, fetch_pending_dec, fetch_pending_empty, fetch_pending_full : std_logic;
    signal fetch_command_inc, fetch_command_dec, fetch_command_empty, fetch_command_full : std_logic;
    -- pre-decode
    signal fetch_instr_dat_decompressed : std_logic_vector(31 downto 0);
    signal fetch_instr_rs1_adr_decompressed, fetch_instr_rs2_adr_decompressed : std_logic_vector(4 downto 0);
    -- decode
    signal decode_enable, decode_flush, decode_valid_q : std_logic;
    signal decode_instr_dat_q, decode_pc_q, decode_nxt_pc, decode_pc_incr : std_logic_vector(31 downto 0);
    signal decode_opcode : std_logic_vector(6 downto 0);
    signal decode_funct3 : std_logic_vector(2 downto 0);
    signal decode_funct7 : std_logic_vector(6 downto 0);
    signal decode_instr_rvc_q : std_logic;
    signal decode_jump, decode_branch, decode_sys, decode_muldiv : std_logic;
    signal decode_rs1_en, decode_rs2_en, decode_rd_we, decode_rd_is_zero : std_logic;
    signal decode_rs1_adr, decode_rs2_adr, decode_rd_adr : std_logic_vector(4 downto 0);
    signal decode_rs1_dat, decode_rs2_dat : std_logic_vector(31 downto 0);
    signal decode_imm_i, decode_imm_s, decode_imm_b, decode_imm_u, decode_imm_j : std_logic_vector(31 downto 0);
    signal decode_alu_a_src1, decode_alu_a_src2 : std_logic_vector(31 downto 0);
    signal decode_alu_a_op : std_logic_vector(1 downto 0);
    signal decode_alu_a_arith : std_logic;
    signal decode_alu_a_res_sel : std_logic_vector(2 downto 0);
    signal decode_cmp_signed : std_logic;
    signal decode_alu_b_src1, decode_alu_b_src2 : std_logic_vector(31 downto 0);
    signal decode_lsu_valid, decode_lsu_load, decode_lsu_store : std_logic;
    -- execute
    signal execute_enable, execute_flush, execute_valid_q, execute_rd_we_q, execute_lsu_valid_q, execute_load_q, execute_store_q: std_logic;
    signal execute_rd_adr_q : std_logic_vector(4 downto 0);
    signal execute_funct3_q : std_logic_vector(2 downto 0);
    signal execute_funct7_q : std_logic_vector(6 downto 0);
    signal execute_jump_q, execute_branch_q, execute_branch, execute_sys_q, execute_muldiv_q : std_logic;
    signal execute_alu_a_src1_q, execute_alu_a_src2_q, execute_alu_a_r, execute_alu_a_res : std_logic_vector(31 downto 0);
    signal execute_alu_a_op_q : std_logic_vector(1 downto 0);
    signal execute_alu_a_arith_q : std_logic;
    signal execute_alu_a_res_sel_q : std_logic_vector(2 downto 0);
    signal execute_alu_b_src1_q, execute_alu_b_src2_q, execute_alu_b_res : std_logic_vector(31 downto 0);
    signal execute_shifter_res : std_logic_vector(31 downto 0);
    signal execute_shifter_rdy : std_logic;
    signal execute_cmp_signed_q, execute_cmp_lt, execute_cmp_eq : std_logic;
    signal execute_mem_data : std_logic_vector(31 downto 0);
    -- memory
    signal memory_enable, memory_flush, memory_valid_q, memory_rd_we_q : std_logic;
    signal memory_funct3_q : std_logic_vector(2 downto 0);
    signal memory_rd_adr_q : std_logic_vector(4 downto 0);
    signal memory_alu_a_res_q, memory_alu_b_res_q, memory_alu_a_res : std_logic_vector(31 downto 0);
    signal memory_branch_q, memory_load_q, memory_sys_q, memory_muldiv_q : std_logic;
    signal memory_mem_dat : std_logic_vector(31 downto 0);
    -- writeback
    signal writeback_enable, writeback_flush, writeback_valid_q, writeback_rd_we_q, writeback_rd_we : std_logic;
    signal writeback_funct3_q : std_logic_vector(2 downto 0);
    signal writeback_rd_adr_q : std_logic_vector(4 downto 0);
    signal writeback_alu_a_res_q, writeback_mem_dat_q, writeback_mem_dat, writeback_rd_dat : std_logic_vector(31 downto 0);
    signal writeback_load_q, writeback_muldiv_q : std_logic;
    signal writeback_mem_adr_q : std_logic_vector(1 downto 0);
    -- branch
    signal branch_load_pc : std_logic;
    signal branch_target_pc : std_logic_vector(31 downto 0);
    -- lsu
    signal lsu_flush, lsu_cmd_rdy, lsu_rsp_rdy : std_logic;
    signal lsu_misaligned_store, lsu_misaligned_load : std_logic;
    -- ctl
    signal ctl_fetch_stall, ctl_decode_stall, ctl_execute_stall, ctl_memory_stall, ctl_writeback_stall : std_logic;
    signal ctl_decode_execute_rs1_match, ctl_decode_memory_rs1_match, ctl_decode_writeback_rs1_match, ctl_decode_regfile_rs1_match : std_logic;
    signal ctl_decode_execute_rs2_match, ctl_decode_memory_rs2_match, ctl_decode_writeback_rs2_match, ctl_decode_regfile_rs2_match : std_logic;
    signal ctl_decode_execute_rs1_hazard, ctl_decode_memory_rs1_hazard, ctl_decode_writeback_rs1_hazard, ctl_decode_regfile_rs1_hazard : std_logic;
    signal ctl_decode_execute_rs2_hazard, ctl_decode_memory_rs2_hazard, ctl_decode_writeback_rs2_hazard, ctl_decode_regfile_rs2_hazard : std_logic;
    signal ctl_decode_rs1_hazard, ctl_decode_rs2_hazard : std_logic;
    signal ctl_decode_execute_rs1_forward, ctl_decode_memory_rs1_forward, ctl_decode_writeback_rs1_forward, ctl_decode_regfile_rs1_forward : std_logic;
    signal ctl_decode_execute_rs2_forward, ctl_decode_memory_rs2_forward, ctl_decode_writeback_rs2_forward, ctl_decode_regfile_rs2_forward : std_logic;
    signal ctl_decode_execute_csr_hazard : std_logic;
    -- regfile
    signal regfile_rs1_en, regfile_rs2_en, regfile_rd_we, regfile_rd_we_q : std_logic;
    signal regfile_rs1_adr, regfile_rs2_adr, regfile_rd_adr, regfile_rd_adr_q : std_logic_vector(4 downto 0);
    signal regfile_rs1_dat, regfile_rs2_dat, regfile_rd_dat, regfile_rd_dat_q : std_logic_vector(31 downto 0);
    -- memory interface
    signal data_cmd_adr, data_cmd_dat : std_logic_vector(31 downto 0);
    signal data_cmd_vld, data_cmd_we : std_logic;
    signal data_cmd_siz : std_logic_vector(1 downto 0);
    -- csr
    signal csr_load_pc : std_logic;
    signal csr_target_pc : std_logic_vector(31 downto 0);
    signal csr_read_data : std_logic_vector(31 downto 0);
    signal csr_trap_entry, csr_trap_exit : std_logic;
    signal csr_trap_entry_vect, csr_trap_exit_vect, csr_trap_exception_pc : std_logic_vector(31 downto 0);
    signal csr_trap_exception, csr_trap_interrupt : std_logic;
    -- muldiv
    signal muldiv_rdy : std_logic;
    signal muldiv_res : std_logic_vector(31 downto 0);
    -- debug module
    signal debug_mode_q, debug_reset : std_logic;
    signal debug_instr_cmd_vld, debug_instr_cmd_rdy, debug_instr_rsp_vld : std_logic;
    signal debug_instr_rsp_dat : std_logic_vector(31 downto 0);
    signal debug_mode_sel_q : std_logic;
begin

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            booted_q <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' or debug_reset = '1' or booted_q = '0' then
                booted_q <= not (srst_i or debug_reset);
            end if;
        end if;
    end process;

    instr_cmd_rdy <= (not debug_mode_q and instr_cmd_rdy_i)     or (debug_mode_q and debug_instr_cmd_rdy);
    instr_rsp_vld <= (not debug_mode_sel_q and instr_rsp_vld_i) or (debug_mode_sel_q and debug_instr_rsp_vld);
    instr_rsp_dat <= instr_rsp_dat_i when debug_mode_sel_q = '0' else debug_instr_rsp_dat;

-- Fetch stage
    fetch_load_pc_en <= branch_load_pc;
    fetch_target_pc  <= branch_target_pc;

    fetch_instr_cmd_vld <= booted_q and not fetch_stall and not fetch_command_full and not fetch_flush_q;

    fetch_nxt_pc <=
        fetch_target_pc when fetch_load_pc_en = '1' else
        std_logic_vector(unsigned(fetch_pc_q) + 4);

    fetch_pc_en <= (fetch_load_pc_en or (instr_cmd_rdy and not fetch_stall and not fetch_command_full and not fetch_flush_q));

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if fetch_pc_en = '1' then
                fetch_pc_q <= fetch_nxt_pc;
            end if;
        end if;
    end process;

    fetch_fifo_clr  <= fetch_flush;
    fetch_fifo_we   <= (not fetch_enable or not fetch_fifo_ef) and instr_rsp_vld;
    fetch_fifo_wdat <= instr_rsp_dat;
    fetch_fifo_re   <= fetch_enable and not fetch_fifo_ef;

    u_fetch_fifo : entity work.cpu_fifo
        generic map (
            G_FIFO_DEPTH => C_FETCH_FIFO_DEPTH,
            G_FIFO_WIDTH => 32
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => fetch_fifo_clr,
            we_i => fetch_fifo_we,
            wdata_i => fetch_fifo_wdat,
            re_i => fetch_fifo_re,
            rdata_o => fetch_fifo_rdat,
            empty_o => fetch_fifo_ef,
            full_o => fetch_fifo_ff
        );

    fetch_instr_raw_dat <= instr_rsp_dat when fetch_fifo_ef = '1' else fetch_fifo_rdat;
    fetch_instr_raw_vld <= ((instr_rsp_vld and fetch_fifo_ef) or not fetch_fifo_ef) and not fetch_flush_q;

    fetch_pending_inc <= fetch_instr_cmd_vld and instr_cmd_rdy;
    fetch_pending_dec <= instr_rsp_vld;
    fetch_command_inc <= fetch_pending_inc;
    fetch_command_dec <= decode_enable and fetch_instr_raw_vld;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            fetch_pending_cnt_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if fetch_pending_inc = '1' and fetch_pending_dec = '0' then
                fetch_pending_cnt_q <= fetch_pending_cnt_q + 1;
            elsif fetch_pending_inc = '0' and fetch_pending_dec = '1' then
                fetch_pending_cnt_q <= fetch_pending_cnt_q - 1;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if fetch_flush = '1' or fetch_flush_q = '1' then
                fetch_command_cnt_q <= (others => '0');
            elsif fetch_command_inc = '1' and fetch_command_dec = '0' then
                fetch_command_cnt_q <= fetch_command_cnt_q + 1;
            elsif fetch_command_inc = '0' and fetch_command_dec = '1' then
                fetch_command_cnt_q <= fetch_command_cnt_q - 1;
            end if;
        end if;
    end process;

    fetch_pending_empty <= '1' when fetch_pending_cnt_q = 0 and fetch_pending_inc = '0' else '0';
    fetch_pending_full  <= fetch_pending_cnt_q(fetch_pending_cnt_q'left) and not fetch_pending_dec;
    fetch_command_empty <= '1' when fetch_command_cnt_q = 0 and fetch_command_inc = '0' else '0';
    fetch_command_full  <= fetch_command_cnt_q(fetch_command_cnt_q'left) and not fetch_command_dec;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if fetch_flush = '1' or fetch_pending_empty = '1' then
                fetch_flush_q <= not fetch_pending_empty;
            end if;
        end if;
    end process;

    gen_aligner: if G_EXTENSION_C = TRUE generate
        u_instr_align : entity work.instruction_aligner
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                enable_i => fetch_enable,
                load_pc_i => fetch_load_pc_en,
                target_pc_i => fetch_target_pc,
                instr_vld_i => fetch_instr_raw_vld,
                instr_dat_i => fetch_instr_raw_dat,
                instr_vld_o => fetch_instr_vld_align,
                instr_dat_o => fetch_instr_dat_align,
                instr_rvc_o => fetch_instr_rvc,
                stall_o => fetch_stall
            );
    end generate gen_aligner;

    gen_no_aligner: if G_EXTENSION_C = FALSE generate
        fetch_instr_vld_align <= fetch_instr_raw_vld;
        fetch_instr_dat_align <= fetch_instr_raw_dat;
        fetch_instr_rvc       <= '0';
        fetch_stall           <= '0';
    end generate gen_no_aligner;

    debug_instr_cmd_vld <= fetch_instr_cmd_vld and debug_mode_q;

    instr_cmd_adr_o <= fetch_pc_q;
    instr_cmd_vld_o <= fetch_instr_cmd_vld and not debug_mode_q;

-- Pre-decode
    gen_decompressor: if G_EXTENSION_C = TRUE generate
        u_decompressor : entity work.decompressor
            generic map (
                G_CATCH_ILLEGAL => C_CATCH_ILLEGAL
            )
            port map (
                instr_i => fetch_instr_dat_align(15 downto 0),
                instr_o => fetch_instr_dat_decompressed,
                rs1_adr_o => fetch_instr_rs1_adr_decompressed,
                rs2_adr_o => fetch_instr_rs2_adr_decompressed
            );
    end generate gen_decompressor;
    gen_no_decompressor: if G_EXTENSION_C = FALSE generate
        fetch_instr_rs1_adr_decompressed <= (others => '-');
        fetch_instr_rs2_adr_decompressed <= (others => '-');
        fetch_instr_dat_decompressed     <= (others => '-');
    end generate gen_no_decompressor;

    fetch_rs1_adr   <= fetch_instr_rs1_adr_decompressed when fetch_instr_rvc = '1' else fetch_instr_dat_align(19 downto 15);
    fetch_rs2_adr   <= fetch_instr_rs2_adr_decompressed when fetch_instr_rvc = '1' else fetch_instr_dat_align(24 downto 20);
    fetch_instr_dat <= fetch_instr_dat_decompressed     when fetch_instr_rvc = '1' else fetch_instr_dat_align;
    fetch_instr_vld <= fetch_instr_vld_align;

-- Decode stage
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            decode_valid_q <= '0';
        elsif rising_edge(clk_i) then
            if decode_enable = '1' then
                decode_valid_q <= fetch_instr_vld and not decode_flush;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if decode_enable = '1' then
                decode_instr_dat_q <= fetch_instr_dat;
                decode_instr_rvc_q <= fetch_instr_rvc;
                if branch_load_pc = '1' then
                    decode_pc_q <= branch_target_pc;
                else
                    decode_pc_q <= decode_nxt_pc;
                end if;
            end if;
        end if;
    end process;

    decode_pc_incr <=
        std_logic_vector(to_unsigned(2, decode_pc_incr'length)) when decode_instr_rvc_q = '1' and G_EXTENSION_C = TRUE else
        std_logic_vector(to_unsigned(4, decode_pc_incr'length));

    decode_nxt_pc  <= std_logic_vector(unsigned(decode_pc_q) + unsigned(decode_pc_incr and (31 downto 0 => decode_valid_q)));

    decode_opcode <= decode_instr_dat_q(06 downto 02) & "11";
    decode_funct3 <= decode_instr_dat_q(14 downto 12);
    decode_funct7 <= decode_instr_dat_q(31 downto 25);
    decode_imm_i <= (31 downto 12 => decode_instr_dat_q(31)) & decode_instr_dat_q(31 downto 20);
    decode_imm_s <= (31 downto 12 => decode_instr_dat_q(31)) & decode_instr_dat_q(31 downto 25) & decode_instr_dat_q(11 downto 7);
    decode_imm_b <= (31 downto 12 => decode_instr_dat_q(31)) & decode_instr_dat_q(7) & decode_instr_dat_q(30 downto 25) & decode_instr_dat_q(11 downto 8) & '0';
    decode_imm_u <= decode_instr_dat_q(31 downto 12) & (11 downto 0 => '0');
    decode_imm_j <= (31 downto 20 => decode_instr_dat_q(31)) & decode_instr_dat_q(19 downto 12) & decode_instr_dat_q(20) & decode_instr_dat_q(30 downto 21) & '0';
    decode_rs1_adr <= decode_instr_dat_q(19 downto 15);
    decode_rs2_adr <= decode_instr_dat_q(24 downto 20);
    decode_rd_adr  <= decode_instr_dat_q(11 downto 07);

    process (decode_opcode, decode_rs1_dat, decode_rs2_dat, decode_pc_q, decode_pc_incr, decode_imm_u, decode_imm_i)
    begin
        decode_alu_a_src1 <= (others => '-');
        decode_alu_a_src2 <= (others => '-');
        case decode_opcode is
            when RV32I_OP_LUI     => decode_alu_a_src1 <= (others => '0'); decode_alu_a_src2 <= decode_imm_u;
            when RV32I_OP_AUIPC   => decode_alu_a_src1 <= decode_pc_q; decode_alu_a_src2 <= decode_imm_u;
            when RV32I_OP_JAL     => decode_alu_a_src1 <= decode_pc_q; decode_alu_a_src2 <= decode_pc_incr;
            when RV32I_OP_JALR    => decode_alu_a_src1 <= decode_pc_q; decode_alu_a_src2 <= decode_pc_incr;
            when RV32I_OP_BRANCH  => decode_alu_a_src1 <= decode_rs1_dat; decode_alu_a_src2 <= decode_rs2_dat;
            when RV32I_OP_LOAD    =>
            when RV32I_OP_STORE   => decode_alu_a_src2 <= decode_rs2_dat;
            when RV32I_OP_REG_IMM => decode_alu_a_src1 <= decode_rs1_dat; decode_alu_a_src2 <= decode_imm_i;
            when RV32I_OP_REG_REG => decode_alu_a_src1 <= decode_rs1_dat; decode_alu_a_src2 <= decode_rs2_dat;
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     => if G_EXTENSION_ZICSR = TRUE then decode_alu_a_src1 <= decode_rs1_dat; decode_alu_a_src2 <= decode_imm_i; end if;
            when others =>
        end case;
    end process;

    process (decode_opcode, decode_rs1_dat, decode_pc_q, decode_imm_j, decode_imm_i, decode_imm_b, decode_imm_s)
    begin
        decode_alu_b_src1 <= (others => '-');
        decode_alu_b_src2 <= (others => '-');
        case decode_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   =>
            when RV32I_OP_JAL     => decode_alu_b_src1 <= decode_pc_q; decode_alu_b_src2 <= decode_imm_j;
            when RV32I_OP_JALR    => decode_alu_b_src1 <= decode_rs1_dat; decode_alu_b_src2 <= decode_imm_i;
            when RV32I_OP_BRANCH  => decode_alu_b_src1 <= decode_pc_q; decode_alu_b_src2 <= decode_imm_b;
            when RV32I_OP_LOAD    => decode_alu_b_src1 <= decode_rs1_dat; decode_alu_b_src2 <= decode_imm_i;
            when RV32I_OP_STORE   => decode_alu_b_src1 <= decode_rs1_dat; decode_alu_b_src2 <= decode_imm_s;
            when RV32I_OP_REG_IMM =>
            when RV32I_OP_REG_REG =>
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     =>
            when others =>
        end case;
    end process;

    process (decode_opcode)
    begin
        decode_jump <= '0';
        decode_branch <= '0';
        decode_lsu_load <= '0';
        decode_lsu_store <= '0';
        decode_lsu_valid <= '0';
        decode_sys <= '0';
        case decode_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   =>
            when RV32I_OP_JAL     => decode_jump <= '1';
            when RV32I_OP_JALR    => decode_jump <= '1';
            when RV32I_OP_BRANCH  => decode_branch <= '1';
            when RV32I_OP_LOAD    => decode_lsu_load <= '1'; decode_lsu_valid <= '1';
            when RV32I_OP_STORE   => decode_lsu_store <= '1'; decode_lsu_valid <= '1';
            when RV32I_OP_REG_IMM =>
            when RV32I_OP_REG_REG =>
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     => if G_EXTENSION_ZICSR = TRUE then decode_sys <= '1'; end if;
            when others =>
        end case;
    end process;

    process (decode_opcode, decode_funct3, decode_funct7)
    begin
        decode_alu_a_res_sel <= "001";
        decode_cmp_signed <= '1';
        decode_alu_a_op <= "00";
        decode_alu_a_arith <= '0';
        decode_muldiv <= '0';
        case decode_opcode is
            when RV32I_OP_LUI    =>
            when RV32I_OP_AUIPC  =>
            when RV32I_OP_JAL    =>
            when RV32I_OP_JALR   =>
            when RV32I_OP_BRANCH =>
                case decode_funct3 is
                    when RV32I_FN3_BLTU => decode_cmp_signed <= '0';
                    when RV32I_FN3_BGEU => decode_cmp_signed <= '0';
                    when others =>
                end case;
            when RV32I_OP_REG_IMM =>
                case decode_funct3 is
                    when RV32I_FN3_ADD  =>
                    when RV32I_FN3_SL   => decode_alu_a_res_sel <= "1--";
                    when RV32I_FN3_SLT  => decode_alu_a_res_sel <= "01-";
                    when RV32I_FN3_SLTU => decode_alu_a_res_sel <= "01-"; decode_cmp_signed <= '0';
                    when RV32I_FN3_XOR  => decode_alu_a_op <= "11";
                    when RV32I_FN3_SR   => decode_alu_a_res_sel <= "1--";
                    when RV32I_FN3_OR   => decode_alu_a_op <= "10";
                    when RV32I_FN3_AND  => decode_alu_a_op <= "01";
                    when others =>
                end case;
            when RV32I_OP_REG_REG =>
                if G_EXTENSION_M = TRUE and decode_funct7(0) = '1' then
                    decode_muldiv <= '1';
                end if;
                case decode_funct3 is
                    when RV32I_FN3_ADD  => if decode_funct7(5) = '1' then decode_alu_a_arith <= '1'; end if;
                    when RV32I_FN3_SL   => decode_alu_a_res_sel <= "1--";
                    when RV32I_FN3_SLT  => decode_alu_a_res_sel <= "01-";
                    when RV32I_FN3_SLTU => decode_alu_a_res_sel <= "01-"; decode_cmp_signed <= '0';
                    when RV32I_FN3_XOR  => decode_alu_a_op <= "11";
                    when RV32I_FN3_SR   => decode_alu_a_res_sel <= "1--";
                    when RV32I_FN3_OR   => decode_alu_a_op <= "10";
                    when RV32I_FN3_AND  => decode_alu_a_op <= "01";
                    when others =>
                end case;
            when others =>
        end case;
    end process;

    process (decode_opcode)
    begin
        decode_rs1_en <= '0';
        decode_rs2_en <= '0';
        decode_rd_we <= '0';
        case decode_opcode is
            when RV32I_OP_LUI     => decode_rs1_en <= '0'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_AUIPC   => decode_rs1_en <= '0'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_JAL     => decode_rs1_en <= '0'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_JALR    => decode_rs1_en <= '1'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_BRANCH  => decode_rs1_en <= '1'; decode_rs2_en <= '1'; decode_rd_we <= '0';
            when RV32I_OP_LOAD    => decode_rs1_en <= '1'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_STORE   => decode_rs1_en <= '1'; decode_rs2_en <= '1'; decode_rd_we <= '0';
            when RV32I_OP_REG_IMM => decode_rs1_en <= '1'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_REG_REG => decode_rs1_en <= '1'; decode_rs2_en <= '1'; decode_rd_we <= '1';
            when RV32I_OP_FENCE   => decode_rs1_en <= '0'; decode_rs2_en <= '0'; decode_rd_we <= '1';
            when RV32I_OP_SYS     => if G_EXTENSION_ZICSR = TRUE then decode_rs1_en <= '1'; decode_rs2_en <= '0'; decode_rd_we <= '1'; end if;
            when others =>
        end case;
    end process;
    decode_rd_is_zero <= '1' when unsigned(decode_rd_adr) = 0 else '0';

-- Execute stage
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            execute_valid_q <= '0';
            execute_rd_we_q <= '0';
            execute_lsu_valid_q <= '0';
        elsif rising_edge(clk_i) then
            if execute_enable = '1' then
                if execute_flush = '1' then
                    execute_valid_q     <= '0';
                    execute_rd_we_q     <= '0';
                    execute_lsu_valid_q <= '0';
                else
                    execute_valid_q <= decode_valid_q;
                    execute_rd_we_q <= decode_valid_q and decode_rd_we and not decode_rd_is_zero;
                    execute_lsu_valid_q <= decode_valid_q and decode_lsu_valid;
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if execute_enable = '1' then
                execute_rd_adr_q <= decode_rd_adr;
                execute_alu_a_src1_q <= decode_alu_a_src1;
                execute_alu_a_src2_q <= decode_alu_a_src2;
                execute_alu_a_op_q   <= decode_alu_a_op;
                execute_alu_a_arith_q<= decode_alu_a_arith;
                execute_alu_a_res_sel_q <= decode_alu_a_res_sel;
                execute_alu_b_src1_q <= decode_alu_b_src1;
                execute_alu_b_src2_q <= decode_alu_b_src2;
                execute_funct3_q <= decode_funct3;
                execute_funct7_q <= decode_funct7;
                execute_jump_q <= decode_jump;
                execute_branch_q <= decode_branch;
                execute_load_q  <= decode_lsu_load;
                execute_store_q <= decode_lsu_store;
                execute_cmp_signed_q <= decode_cmp_signed;
                execute_sys_q <= decode_sys;
                execute_muldiv_q <= decode_muldiv;
            end if;
        end if;
    end process;

    u_comparator : entity work.comparator
        port map (
            a_i => execute_alu_a_src1_q,
            b_i => execute_alu_a_src2_q,
            signed_i => execute_cmp_signed_q,
            lt_o => execute_cmp_lt,
            eq_o => execute_cmp_eq
        );

    process (execute_alu_a_op_q, execute_alu_a_arith_q, execute_alu_a_src1_q, execute_alu_a_src2_q)
    begin
        case execute_alu_a_op_q is
            when "00" =>
                if execute_alu_a_arith_q = '0' then
                    execute_alu_a_r <= std_logic_vector(unsigned(execute_alu_a_src1_q) + unsigned(execute_alu_a_src2_q));
                else
                    execute_alu_a_r <= std_logic_vector(unsigned(execute_alu_a_src1_q) - unsigned(execute_alu_a_src2_q));
                end if;
            when "01" => execute_alu_a_r <= execute_alu_a_src1_q and execute_alu_a_src2_q;
            when "10" => execute_alu_a_r <= execute_alu_a_src1_q or  execute_alu_a_src2_q;
            when "11" => execute_alu_a_r <= execute_alu_a_src1_q xor execute_alu_a_src2_q;
            when others => execute_alu_a_r <= (others => '-');
        end case;
    end process;


    block_shifter : block
        signal shifter_vld  : std_logic;
        signal shifter_shmt : std_logic_vector(4 downto 0);
        signal shifter_type : std_logic_vector(1 downto 0);
        signal shifter_data : std_logic_vector(31 downto 0);
    begin
        gen_simple_shifter: if G_FULL_BARREL_SHIFTER = FALSE generate
            shifter_shmt <= decode_rs2_dat(4 downto 0) when decode_opcode(5) = '1' else decode_imm_i(4 downto 0);
            shifter_type <= decode_funct3(2) & decode_funct7(5);
            shifter_vld  <= execute_enable and decode_valid_q and decode_alu_a_res_sel(2);
            shifter_data <= decode_rs1_dat;
        end generate gen_simple_shifter;
        gen_full_barrel_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
            shifter_shmt <= execute_alu_a_src2_q(4 downto 0);
            shifter_type <= execute_funct3_q(2) & execute_funct7_q(5);
            shifter_vld  <= '0';
            shifter_data <= execute_alu_a_src1_q;
        end generate gen_full_barrel_shifter;
        u_shifter : entity work.shifter
            generic map (
                G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER,
                G_SHIFTER_EARLY_INJECTION => TRUE
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                srst_i => '0',
                type_i => shifter_type,
                shmt_i => shifter_shmt,
                valid_i => shifter_vld,
                data_i => shifter_data,
                valid_o => open,
                data_o => execute_shifter_res,
                ready_o => execute_shifter_rdy
            );
    end block;

    process (execute_alu_a_res_sel_q, execute_shifter_res, execute_cmp_lt, execute_alu_a_r)
    begin
        if execute_alu_a_res_sel_q(2) = '1' then
            execute_alu_a_res <= execute_shifter_res;
        elsif execute_alu_a_res_sel_q(1) = '1' then
            execute_alu_a_res <= (31 downto 1 => '0') & execute_cmp_lt;
        elsif execute_alu_a_res_sel_q(0) = '1' then
            execute_alu_a_res <= execute_alu_a_r;
        else
            execute_alu_a_res <= (others => '-');
        end if;
    end process;

    execute_alu_b_res <= std_logic_vector(unsigned(execute_alu_b_src1_q) + unsigned(execute_alu_b_src2_q));

    process (execute_jump_q, execute_branch_q, execute_funct3_q, execute_cmp_lt, execute_cmp_eq)
    begin
        execute_branch <= '0';
        if execute_jump_q = '1' then
            execute_branch <= '1';
        elsif execute_branch_q = '1' and execute_funct3_q(2) = '1' and (execute_cmp_lt xor execute_funct3_q(0)) = '1' then
            execute_branch <= '1';
        elsif execute_branch_q = '1' and execute_funct3_q(2) = '0' and (execute_cmp_eq xor execute_funct3_q(0)) = '1' then
            execute_branch <= '1';
        end if;
    end process;

    process (execute_funct3_q, execute_alu_a_src2_q)
    begin
        case execute_funct3_q(1 downto 0) is
            when RV32I_FN3_SB => execute_mem_data <= execute_alu_a_src2_q(7 downto 0) & execute_alu_a_src2_q(7 downto 0) & execute_alu_a_src2_q(7 downto 0) & execute_alu_a_src2_q(7 downto 0);
            when RV32I_FN3_SH => execute_mem_data <= execute_alu_a_src2_q(15 downto 0) & execute_alu_a_src2_q(15 downto 0);
            when RV32I_FN3_SW => execute_mem_data <= execute_alu_a_src2_q;
            when others => execute_mem_data <= (others => '-');
        end case;
    end process;

    gen_muldiv: if G_EXTENSION_M = TRUE generate
        signal muldiv_en, muldiv_flush : std_logic;
    begin
        muldiv_en <= decode_muldiv and decode_valid_q and execute_enable and not (ctl_decode_rs1_hazard or ctl_decode_rs2_hazard or ctl_decode_execute_csr_hazard);
        muldiv_flush <= '1' when branch_load_pc = '1' and (memory_muldiv_q = '0' and writeback_muldiv_q = '0') else '0';

        u_muldiv : entity work.muldiv
            generic map (
                G_FAST_MUL => G_FAST_MUL
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                enable_i => muldiv_en,
                flush_i => muldiv_flush,
                funct3_i => decode_funct3,
                rs1_dat_i => decode_rs1_dat,
                rs2_dat_i => decode_rs2_dat,
                result_o => muldiv_res,
                ready_o => muldiv_rdy
            );
    end generate gen_muldiv;

    gen_no_muldiv: if G_EXTENSION_M = FALSE generate
        muldiv_rdy <= '1';
        muldiv_res <= (others => '-');
    end generate gen_no_muldiv;

-- Memory stage
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            memory_valid_q <= '0';
            memory_rd_we_q <= '0';
            memory_branch_q <= '0';
        elsif rising_edge(clk_i) then
            if memory_enable = '1' then
                memory_valid_q  <= execute_valid_q and not memory_flush;
                memory_rd_we_q  <= execute_rd_we_q and not memory_flush;
                memory_branch_q <= execute_valid_q and execute_branch and not memory_flush;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_enable = '1' then
                memory_funct3_q <= execute_funct3_q;
                memory_rd_adr_q <= execute_rd_adr_q;
                memory_alu_a_res_q <= execute_alu_a_res;
                memory_alu_b_res_q <= execute_alu_b_res;
                memory_load_q <= execute_load_q;
                memory_sys_q <= execute_sys_q;
                memory_muldiv_q <= execute_muldiv_q;
            end if;
        end if;
    end process;

    memory_alu_a_res <=
        csr_read_data      when memory_rd_we_q = '1' and  memory_sys_q = '1' and G_EXTENSION_ZICSR = TRUE   else
        memory_alu_a_res_q when memory_rd_we_q = '1' and (memory_sys_q = '0' or  G_EXTENSION_ZICSR = FALSE) else
        (others => '-');

-- Writeback stage
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            writeback_valid_q <= '0';
            writeback_rd_we_q <= '0';
        elsif rising_edge(clk_i) then
            if writeback_enable = '1' then
                writeback_valid_q <= memory_valid_q and not writeback_flush;
                writeback_rd_we_q <= memory_rd_we_q and not writeback_flush;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if writeback_enable = '1' then
                writeback_rd_adr_q <= memory_rd_adr_q;
                writeback_funct3_q <= memory_funct3_q;
                writeback_alu_a_res_q <= memory_alu_a_res;
                writeback_mem_dat_q <= memory_mem_dat;
                writeback_mem_adr_q <= memory_alu_b_res_q(1 downto 0);
                writeback_load_q <= memory_load_q;
                writeback_muldiv_q <= memory_muldiv_q;
            end if;
        end if;
    end process;

    process (writeback_funct3_q, writeback_mem_adr_q, writeback_mem_dat_q)
        variable writeback_mem_dat_var : std_logic_vector(31 downto 0);
    begin
        writeback_mem_dat_var := writeback_mem_dat_q;
        case writeback_mem_adr_q is
            when "01" => writeback_mem_dat_var(07 downto 0) := writeback_mem_dat_q(15 downto 8);
            when "10" => writeback_mem_dat_var(15 downto 0) := writeback_mem_dat_q(31 downto 16);
            when "11" => writeback_mem_dat_var(07 downto 0) := writeback_mem_dat_q(31 downto 24);
            when others =>
        end case;
        writeback_mem_dat <= (others => '-');
        case writeback_funct3_q(1 downto 0) is
            when RV32I_FN3_LB => writeback_mem_dat <= (31 downto 8  => not writeback_funct3_q(2) and writeback_mem_dat_var(07)) & writeback_mem_dat_var(07 downto 0);
            when RV32I_FN3_LH => writeback_mem_dat <= (31 downto 16 => not writeback_funct3_q(2) and writeback_mem_dat_var(15)) & writeback_mem_dat_var(15 downto 0);
            when RV32I_FN3_LW => writeback_mem_dat <= writeback_mem_dat_var;
            when others =>
        end case;
    end process;

    writeback_rd_dat <=
        muldiv_res when writeback_rd_we_q = '1' and writeback_load_q = '0' and writeback_muldiv_q = '1' and G_EXTENSION_M = TRUE else
        writeback_mem_dat when writeback_rd_we_q = '1' and writeback_load_q = '1' and (writeback_muldiv_q = '0' or G_EXTENSION_M = FALSE) else
        writeback_alu_a_res_q when writeback_rd_we_q = '1' and writeback_load_q = '0' and (writeback_muldiv_q = '0' or G_EXTENSION_M = FALSE) else
        (others => '-');

    writeback_rd_we <=
        '1' when writeback_rd_we_q = '1' and  writeback_muldiv_q = '1' and muldiv_rdy = '1' and G_EXTENSION_M = TRUE else
        '1' when writeback_rd_we_q = '1' and (writeback_muldiv_q = '0' or G_EXTENSION_M = FALSE) else
        '0';

-- LSU
    lsu_flush <= branch_load_pc;

    u_lsu : entity work.lsu
        generic map (
            G_TWO_CYCLES_READ => C_TWO_CYCLES_READ,
            G_CATCH_MISALIGNED => C_CATCH_MISALIGNED_LOAD_STORE
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            enable_i => memory_enable,
            valid_i => execute_lsu_valid_q,
            flush_i => lsu_flush,
            address_i => execute_alu_b_res,
            data_i => execute_mem_data,
            load_i => execute_load_q,
            store_i => execute_store_q,
            size_i => execute_funct3_q,
            data_o => memory_mem_dat,
            cmd_adr_o => data_cmd_adr,
            cmd_dat_o => data_cmd_dat,
            cmd_siz_o => data_cmd_siz,
            cmd_vld_o => data_cmd_vld,
            cmd_we_o => data_cmd_we,
            cmd_rdy_i => data_cmd_rdy_i,
            rsp_dat_i => data_rsp_dat_i,
            rsp_vld_i => data_rsp_vld_i,
            cmd_rdy_o => lsu_cmd_rdy,
            rsp_rdy_o => lsu_rsp_rdy,
            load_misaligned_o => lsu_misaligned_load,
            store_misaligned_o => lsu_misaligned_store
        );

    data_cmd_adr_o <= data_cmd_adr;
    data_cmd_vld_o <= data_cmd_vld;
    data_cmd_we_o <= data_cmd_we;
    data_cmd_dat_o <= data_cmd_dat;
    data_cmd_siz_o <= data_cmd_siz;

-- Branch
    branch_load_pc   <= memory_branch_q or csr_load_pc or not booted_q;
    branch_target_pc <=
        G_BOOT_ADDRESS when booted_q = '0' else
        csr_target_pc when csr_load_pc = '1' else
        memory_alu_b_res_q when memory_branch_q = '1' else
        (others => '-');

-- Regfile
    regfile_rs1_adr <= decode_rs1_adr when decode_enable = '0' else fetch_rs1_adr;
    regfile_rs1_en  <= '1';
    regfile_rs2_adr <= decode_rs2_adr when decode_enable = '0' else fetch_rs2_adr;
    regfile_rs2_en  <= '1';
    regfile_rd_adr <= writeback_rd_adr_q;
    regfile_rd_dat <= writeback_rd_dat;
    regfile_rd_we  <= writeback_rd_we;

    u_regfile : entity work.regfile
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => '0',
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

-- ctl
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            regfile_rd_we_q  <= regfile_rd_we;
            regfile_rd_adr_q <= regfile_rd_adr;
            regfile_rd_dat_q <= regfile_rd_dat;
        end if;
    end process;

    ctl_decode_execute_rs1_match   <= '1' when decode_rs1_adr = execute_rd_adr_q else '0';
    ctl_decode_execute_rs2_match   <= '1' when decode_rs2_adr = execute_rd_adr_q else '0';
    ctl_decode_memory_rs1_match    <= '1' when decode_rs1_adr = memory_rd_adr_q else '0';
    ctl_decode_memory_rs2_match    <= '1' when decode_rs2_adr = memory_rd_adr_q else '0';
    ctl_decode_writeback_rs1_match <= '1' when decode_rs1_adr = writeback_rd_adr_q else '0';
    ctl_decode_writeback_rs2_match <= '1' when decode_rs2_adr = writeback_rd_adr_q else '0';
    ctl_decode_regfile_rs1_match   <= '1' when decode_rs1_adr = regfile_rd_adr_q else '0';
    ctl_decode_regfile_rs2_match   <= '1' when decode_rs2_adr = regfile_rd_adr_q else '0';

    ctl_decode_execute_rs1_hazard   <= '1' when execute_rd_we_q = '1' and ctl_decode_execute_rs1_match = '1' and (execute_load_q = '1' or G_EXECUTE_BYPASS = FALSE) else '0';
    ctl_decode_execute_rs2_hazard   <= '1' when execute_rd_we_q = '1' and ctl_decode_execute_rs2_match = '1' and (execute_load_q = '1' or G_EXECUTE_BYPASS = FALSE) else '0';
    ctl_decode_memory_rs1_hazard    <= '1' when memory_rd_we_q = '1' and ctl_decode_memory_rs1_match = '1' and (memory_load_q = '1' or G_MEMORY_BYPASS = FALSE) else '0';
    ctl_decode_memory_rs2_hazard    <= '1' when memory_rd_we_q = '1' and ctl_decode_memory_rs2_match = '1' and (memory_load_q = '1' or G_MEMORY_BYPASS = FALSE) else '0';
    ctl_decode_writeback_rs1_hazard <= '1' when writeback_rd_we_q = '1' and ctl_decode_writeback_rs1_match = '1' and G_WRITEBACK_BYPASS = FALSE else '0';
    ctl_decode_writeback_rs2_hazard <= '1' when writeback_rd_we_q = '1' and ctl_decode_writeback_rs2_match = '1' and G_WRITEBACK_BYPASS = FALSE else '0';
    ctl_decode_regfile_rs1_hazard   <= '1' when regfile_rd_we_q = '1' and ctl_decode_regfile_rs1_match = '1' and G_REGFILE_BYPASS = FALSE else '0';
    ctl_decode_regfile_rs2_hazard   <= '1' when regfile_rd_we_q = '1' and ctl_decode_regfile_rs2_match = '1' and G_REGFILE_BYPASS = FALSE else '0';

    ctl_decode_execute_csr_hazard    <= execute_valid_q and execute_sys_q;

    ctl_decode_execute_rs1_forward   <= '1' when execute_rd_we_q = '1' and ctl_decode_execute_rs1_match = '1' and G_EXECUTE_BYPASS = TRUE else '0';
    ctl_decode_execute_rs2_forward   <= '1' when execute_rd_we_q = '1' and ctl_decode_execute_rs2_match = '1' and G_EXECUTE_BYPASS = TRUE else '0';
    ctl_decode_memory_rs1_forward    <= '1' when memory_rd_we_q = '1' and ctl_decode_memory_rs1_match = '1' and G_MEMORY_BYPASS = TRUE else '0';
    ctl_decode_memory_rs2_forward    <= '1' when memory_rd_we_q = '1' and ctl_decode_memory_rs2_match = '1' and G_MEMORY_BYPASS = TRUE else '0';
    ctl_decode_writeback_rs1_forward <= '1' when writeback_rd_we_q = '1' and ctl_decode_writeback_rs1_match = '1' and G_WRITEBACK_BYPASS = TRUE else '0';
    ctl_decode_writeback_rs2_forward <= '1' when writeback_rd_we_q = '1' and ctl_decode_writeback_rs2_match = '1' and G_WRITEBACK_BYPASS = TRUE else '0';
    ctl_decode_regfile_rs1_forward   <= '1' when regfile_rd_we_q = '1' and ctl_decode_regfile_rs1_match = '1' and G_REGFILE_BYPASS = TRUE else '0';
    ctl_decode_regfile_rs2_forward   <= '1' when regfile_rd_we_q = '1' and ctl_decode_regfile_rs2_match = '1' and G_REGFILE_BYPASS = TRUE else '0';

    ctl_decode_rs1_hazard <= '1' when decode_rs1_en = '1' and (ctl_decode_execute_rs1_hazard = '1' or ctl_decode_memory_rs1_hazard = '1' or ctl_decode_writeback_rs1_hazard = '1' or ctl_decode_regfile_rs1_hazard = '1') else '0';
    ctl_decode_rs2_hazard <= '1' when decode_rs2_en = '1' and (ctl_decode_execute_rs2_hazard = '1' or ctl_decode_memory_rs2_hazard = '1' or ctl_decode_writeback_rs2_hazard = '1' or ctl_decode_regfile_rs2_hazard = '1') else '0';

    decode_rs1_dat <=
        execute_alu_a_res when ctl_decode_execute_rs1_forward   = '1' else
        memory_alu_a_res  when ctl_decode_memory_rs1_forward    = '1' else
        writeback_rd_dat  when ctl_decode_writeback_rs1_forward = '1' else
        regfile_rd_dat_q  when ctl_decode_regfile_rs1_forward   = '1' else
        regfile_rs1_dat;

    decode_rs2_dat <=
        execute_alu_a_res when ctl_decode_execute_rs2_forward   = '1' else
        memory_alu_a_res  when ctl_decode_memory_rs2_forward    = '1' else
        writeback_rd_dat  when ctl_decode_writeback_rs2_forward = '1' else
        regfile_rd_dat_q  when ctl_decode_regfile_rs2_forward   = '1' else
        regfile_rs2_dat;


    ctl_fetch_stall <=
        '1' when ctl_decode_stall = '1' else
        '0';
    ctl_decode_stall <=
        '0' when branch_load_pc = '1' else
        '1' when muldiv_rdy = '0' and G_EXTENSION_M = TRUE else
        '1' when ctl_execute_stall = '1' else
        '1' when (ctl_decode_rs1_hazard = '1' or ctl_decode_rs2_hazard = '1') else
        '1' when ctl_decode_execute_csr_hazard = '1' and G_EXTENSION_ZICSR = TRUE else
        '0';
    ctl_execute_stall <=
        '0' when branch_load_pc = '1' else
        '1' when ctl_memory_stall = '1' else
        '1' when execute_shifter_rdy = '0' and G_FULL_BARREL_SHIFTER = FALSE else
        '1' when lsu_cmd_rdy = '0' else
        '0';

    ctl_memory_stall <=
        '1' when lsu_rsp_rdy = '0' else
        '0';
    ctl_writeback_stall <=
        '1' when writeback_rd_we_q = '1' and writeback_muldiv_q = '1' and muldiv_rdy = '0' and G_EXTENSION_M = TRUE else
        '0';

    fetch_flush     <= branch_load_pc;
    decode_flush    <= branch_load_pc;
    execute_flush   <=
        '1' when branch_load_pc = '1' else
        '1' when muldiv_rdy = '0' and G_EXTENSION_M = TRUE else
        '1' when ctl_decode_rs1_hazard = '1' or ctl_decode_rs2_hazard = '1' else
        '1' when ctl_decode_execute_csr_hazard = '1' and G_EXTENSION_ZICSR = TRUE else
        '0';
    memory_flush    <=
        '1' when branch_load_pc = '1' else
        '1' when execute_lsu_valid_q = '1' and data_cmd_rdy_i = '0' else
        '0';
    writeback_flush <=
        '1' when booted_q = '0' else
        '1' when memory_rd_we_q = '1' and memory_load_q = '1' and data_rsp_vld_i = '0' else
        '0';

    fetch_enable     <= not ctl_fetch_stall;
    decode_enable    <= not ctl_decode_stall;
    execute_enable   <= not ctl_execute_stall;
    memory_enable    <= not ctl_memory_stall;
    writeback_enable <= not ctl_writeback_stall;

-- csr
    gen_csr: if G_EXTENSION_ZICSR = TRUE generate
        constant C_IMPL_MRET : boolean := TRUE;
        signal csr_mstatus_q : csr_mstatus_t;
        signal csr_mie_q : csr_mie_t;
        signal csr_q : csr_registers_t;
        signal decode_csr_en, execute_csr_en_q, memory_csr_en_q : std_logic;
        signal csr_read_en, csr_write_en : std_logic;
        signal csr_read_addr, csr_write_addr, csr_write_addr_q : std_logic_vector(11 downto 0);
        signal csr_read_data_q, csr_write_data, csr_write_alu, memory_csr_read_data_q : std_logic_vector(31 downto 0);
        signal csr_write_src1_q : std_logic_vector(31 downto 0);
        signal csr_mscratch_we, csr_mie_we, csr_mstatus_we, csr_mtvec_we, csr_mepc_we, csr_mcause_we : std_logic;
        signal decode_ecall, decode_ebreak, decode_mret : std_logic;
        signal execute_ecall_q, execute_ebreak_q, execute_mret_q : std_logic;
        signal execute_pc_q, memory_pc_q : std_logic_vector(31 downto 0);
        signal execute_zimm_q : std_logic_vector(4 downto 0);
        signal external_interrupt, external_interrupt_q, timer_interrupt, timer_interrupt_q : std_logic;
        signal external_interrupt_en, timer_interrupt_en : std_logic;
        signal ebreak_q, ecall_q, mret_q : std_logic;
        signal exception, exception_q, interrupt, interrupt_q, interrut_en : std_logic;
        signal trap_entry, trap_exit : std_logic;
        signal trap_entry_vect, trap_exit_vect : std_logic_vector(31 downto 0);
        signal epc_nxt : std_logic_vector(31 downto 0);
        signal decode_illegal_opcode, execute_illegal_opcode_q : std_logic;
        signal execute_instr_dat_q, instr_dat_q : std_logic_vector(31 downto 0);
        signal illegal_instr_q : std_logic;
        signal misaligned_store_q, misaligned_load_q : std_logic;
        signal execute_misaligned_instruction, misaligned_instruction_q : std_logic;
        signal mcause_nxt : std_logic_vector(31 downto 0);
        -- debug module
        signal dcsr_ebreakm_q, dcsr_stepie_q, dcsr_step_q : std_logic;
        signal decode_dret, execute_dret_q, dret_q : std_logic;
        signal debug_step, debug_step_q : std_logic;
        signal debug_haltreq, debug_haltreq_q : std_logic;
        signal debug_int, debug_int_q : std_logic;
        signal debug_breakpoint, debug_breakpoint_q : std_logic;
        signal debug_exc, debug_exc_q : std_logic;
        signal csr_dcsr_we, csr_dpc_we, csr_dm_data0_we : std_logic;
        signal debug_trap_entry, debug_trap_exit : std_logic;
    begin
        gen_catch_illegal_instr: if C_CATCH_ILLEGAL = TRUE generate
        begin
            process (decode_instr_dat_q, decode_funct3, decode_funct7)
            begin
                decode_illegal_opcode <= '0';
                case decode_instr_dat_q(6 downto 0) is
                    when RV32I_OP_LUI     =>
                    when RV32I_OP_AUIPC   =>
                    when RV32I_OP_JAL     =>
                    when RV32I_OP_JALR    => if decode_funct3 /= "000" then decode_illegal_opcode <= '1'; end if;
                    when RV32I_OP_BRANCH  =>
                        case decode_funct3 is
                            when RV32I_FN3_BEQ | RV32I_FN3_BNE | RV32I_FN3_BLT | RV32I_FN3_BGE | RV32I_FN3_BLTU | RV32I_FN3_BGEU =>
                            when others => decode_illegal_opcode <= '1';
                        end case;
                    when RV32I_OP_LOAD    =>
                        case decode_funct3 is
                            when "000" | "001" | "010" | "011" | "100" | "101" =>
                            when others => decode_illegal_opcode <= '1';
                        end case;
                    when RV32I_OP_STORE   =>
                        case decode_funct3 is
                            when "000" | "001" | "010" =>
                            when others => decode_illegal_opcode <= '1';
                        end case;
                    when RV32I_OP_REG_IMM =>
                        case decode_funct3 is
                            when RV32I_FN3_SL => if decode_funct7 /= "0000000" then decode_illegal_opcode <= '1'; end if;
                            when RV32I_FN3_SR => if decode_funct7 /= "0000000" and decode_funct7 /= "0100000" then decode_illegal_opcode <= '1'; end if;
                            when others =>
                        end case;
                    when RV32I_OP_REG_REG =>
                        case decode_funct7 is
                            when "0000000" =>
                            when "0000001" => if G_EXTENSION_M = FALSE then decode_illegal_opcode <= '1'; end if;
                            when "0100000" =>
                                case decode_funct3 is
                                    when RV32I_FN3_ADD =>
                                    when RV32I_FN3_SR  =>
                                    when others        => decode_illegal_opcode <= '1';
                                end case;
                            when others    => decode_illegal_opcode <= '1';
                        end case;
                    when RV32I_OP_FENCE   =>
                    when RV32I_OP_SYS     =>
                    when others           => decode_illegal_opcode <= '1';
                end case;
            end process;
        end generate gen_catch_illegal_instr;

        gen_no_illegal_instr_catch: if C_CATCH_ILLEGAL = FALSE generate
            decode_illegal_opcode <= '0';
        end generate gen_no_illegal_instr_catch;

        decode_ecall  <= '1' when decode_opcode = RV32I_OP_SYS and decode_funct3 = "000" and decode_instr_dat_q(31 downto 20) = CSR_FN12_ECALL and C_IMPL_ECALL = TRUE else '0';
        decode_ebreak <= '1' when decode_opcode = RV32I_OP_SYS and decode_funct3 = "000" and decode_instr_dat_q(31 downto 20) = CSR_FN12_EBREAK and C_IMPL_EBREAK = TRUE else '0';
        decode_mret   <= '1' when decode_opcode = RV32I_OP_SYS and decode_funct3 = "000" and decode_instr_dat_q(31 downto 20) = CSR_FN12_MRET and C_IMPL_MRET = TRUE else '0';
        decode_csr_en <= '1' when decode_opcode = RV32I_OP_SYS and decode_funct3 /= "000" else '0';
        decode_dret   <= '1' when decode_opcode = RV32I_OP_SYS and decode_funct3 = "000" and decode_instr_dat_q(31 downto 20) = CSR_FN12_DRET and G_DEBUG_MODULE = TRUE else '0';

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if execute_enable = '1' then
                    execute_ecall_q          <= decode_ecall;
                    execute_ebreak_q         <= decode_ebreak;
                    execute_mret_q           <= decode_mret;
                    execute_zimm_q           <= decode_rs1_adr;
                    execute_pc_q             <= decode_pc_q;
                    execute_csr_en_q         <= decode_csr_en and decode_valid_q;
                    execute_illegal_opcode_q <= decode_illegal_opcode and decode_valid_q;
                    execute_instr_dat_q      <= decode_instr_dat_q;
                    execute_dret_q           <= decode_dret;
                end if;
            end if;
        end process;
        
        execute_misaligned_instruction <=
            '0' when C_CATCH_MISALIGNED_INSTRUCTION = FALSE else
            '1' when unsigned(execute_alu_b_res(1 downto 0)) /= 0 and execute_branch = '1' and G_EXTENSION_C = FALSE else
            '1' when unsigned(execute_alu_b_res(0 downto 0)) /= 0 and execute_branch = '1' and G_EXTENSION_C = TRUE  else
            '0';

        debug_step       <= dcsr_step_q;
        debug_breakpoint <= execute_ebreak_q and dcsr_ebreakm_q;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if memory_enable = '1' then
                    memory_pc_q              <= execute_pc_q;
                    memory_csr_read_data_q   <= csr_read_data_q;
                    instr_dat_q              <= execute_instr_dat_q;

                    ecall_q                  <= execute_ecall_q;
                    ebreak_q                 <= execute_ebreak_q;
                    illegal_instr_q          <= execute_illegal_opcode_q;
                    misaligned_load_q        <= lsu_misaligned_load;
                    misaligned_store_q       <= lsu_misaligned_store;
                    misaligned_instruction_q <= execute_misaligned_instruction;
                    debug_step_q             <= debug_step;
                    debug_breakpoint_q       <= debug_breakpoint;
                    debug_haltreq_q          <= debug_haltreq;
                end if;
            end if;
        end process;

        interrut_en <= csr_q.mstatus(CSR_MSTATUS_MIE) and not debug_mode_q and (not dcsr_step_q or dcsr_stepie_q);
        external_interrupt_en <= csr_q.mie(CSR_MIE_MEIE);
        timer_interrupt_en <= csr_q.mie(CSR_MIE_MTIE);

        external_interrupt <= external_irq_i and external_interrupt_en;
        timer_interrupt    <= timer_irq_i and timer_interrupt_en;

        exception <=
            '1' when execute_ecall_q = '1'
                  or (execute_ebreak_q = '1' and dcsr_ebreakm_q = '0')
                  or execute_illegal_opcode_q = '1'
                  or lsu_misaligned_load = '1'
                  or lsu_misaligned_store = '1'
                  or execute_misaligned_instruction = '1'
                else
            '0';
        interrupt <= '1' when (external_interrupt = '1' or timer_interrupt = '1') and interrut_en = '1' else '0';
        debug_int <= '1' when debug_mode_q = '0' and (debug_haltreq = '1' or debug_step = '1') else '0';
        debug_exc <= '1' when debug_breakpoint = '1' else '0';

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                external_interrupt_q <= external_interrupt;
                timer_interrupt_q    <= timer_interrupt;
            end if;
        end process;

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                memory_csr_en_q <= '0';
                interrupt_q     <= '0';
                exception_q     <= '0';
                mret_q          <= '0';
                debug_int_q     <= '0';
                debug_exc_q     <= '0';
                dret_q          <= '0';
            elsif rising_edge(clk_i) then
                if memory_enable = '1' then
                    memory_csr_en_q <= execute_csr_en_q and execute_valid_q and not memory_flush;
                    exception_q     <= exception and execute_valid_q and not memory_flush;
                    interrupt_q     <= interrupt and not memory_flush;
                    mret_q          <= execute_mret_q and execute_valid_q and not memory_flush;
                    debug_exc_q     <= debug_exc and execute_valid_q and not memory_flush;
                    debug_int_q     <= debug_int and not memory_flush;
                    dret_q          <= execute_dret_q and execute_valid_q and not memory_flush and debug_mode_q;
                end if;
            end if;
        end process;

        trap_entry       <= exception_q or interrupt_q;
        trap_exit        <= mret_q;
        debug_trap_entry <= debug_exc_q or debug_int_q;
        debug_trap_exit  <= dret_q;

        epc_nxt <=
               (memory_pc_q        and (31 downto 0 =>      exception_q))
            or (memory_alu_b_res_q and (31 downto 0 => (not exception_q and interrupt_q) and     memory_branch_q))
            or (execute_pc_q       and (31 downto 0 => (not exception_q and interrupt_q) and not memory_branch_q))
            ;

        csr_load_pc   <= trap_entry or trap_exit or debug_trap_entry or debug_trap_exit;
        csr_target_pc <=
               (trap_entry_vect and (31 downto 0 => trap_entry))
            or (trap_exit_vect  and (31 downto 0 => trap_exit))
            or (csr_q.dpc       and (31 downto 0 => debug_trap_exit))
            ;

        csr_read_en   <= memory_enable and execute_valid_q;
        csr_read_addr <= execute_alu_a_src2_q(11 downto 0);
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if csr_read_en = '1' then
                    csr_read_data_q <= (others => '0');
                    case csr_read_addr is
                        when CSR_MSCRATCH => csr_read_data_q <= csr_q.mscratch;
                        when CSR_MIE      => csr_read_data_q <= csr_q.mie;
                        when CSR_MSTATUS  => csr_read_data_q <= csr_q.mstatus;
                        when CSR_MTVEC    => csr_read_data_q <= csr_q.mtvec;
                        when CSR_MEPC     => csr_read_data_q <= csr_q.mepc;
                        when CSR_MCAUSE   => csr_read_data_q <= csr_q.mcause;
                        when CSR_MTVAL    => csr_read_data_q <= csr_q.mtval;
                        when CSR_DCSR     => csr_read_data_q <= csr_q.dcsr;
                        when CSR_DPC      => csr_read_data_q <= csr_q.dpc;
                        when CSR_DM_DATA0 => csr_read_data_q <= csr_q.dm_data0;
                        when others       =>
                    end case;
                end if;
            end if;
        end process;

        csr_read_data <= csr_read_data_q;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if memory_enable = '1' then
                    csr_write_src1_q <= execute_alu_a_src1_q;
                    if execute_funct3_q(2) = '1' then
                        csr_write_src1_q <= (31 downto 5 => '0') & execute_zimm_q;
                    end if;
                end if;
            end if;
        end process;

        process (memory_funct3_q, csr_write_src1_q, csr_read_data_q)
            variable csr_alu_op_a, csr_alu_op_b : std_logic_vector(31 downto 0);
        begin
            csr_alu_op_a := csr_write_src1_q;
            csr_alu_op_b := csr_read_data_q;
            case memory_funct3_q(1 downto 0) is
                when "10"   => csr_write_alu <= csr_alu_op_a or      csr_alu_op_b;
                when "11"   => csr_write_alu <= csr_alu_op_a and not csr_alu_op_b;
                when others => csr_write_alu <= csr_alu_op_a;
            end case;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if memory_enable = '1' then
                    csr_write_addr_q <= execute_alu_a_src2_q(11 downto 0);
                end if;
            end if;
        end process;

        csr_write_addr <= csr_write_addr_q;
        csr_write_data <= csr_write_alu;
        csr_write_en   <= memory_csr_en_q;

        process (csr_write_addr)
        begin
            csr_mscratch_we <= '0';
            csr_mie_we      <= '0';
            csr_mstatus_we  <= '0';
            csr_mtvec_we    <= '0';
            csr_mepc_we     <= '0';
            csr_mcause_we   <= '0';
            csr_dcsr_we     <= '0';
            csr_dpc_we      <= '0';
            csr_dm_data0_we <= '0';
            case csr_write_addr is
                when CSR_MSCRATCH => csr_mscratch_we <= '1';
                when CSR_MIE      => csr_mie_we      <= '1';
                when CSR_MSTATUS  => csr_mstatus_we  <= '1';
                when CSR_MTVEC    => csr_mtvec_we    <= '1';
                when CSR_MEPC     => csr_mepc_we     <= '1';
                when CSR_MCAUSE   => csr_mcause_we   <= '1';
                when CSR_MTVAL    =>
                when CSR_DCSR     => csr_dcsr_we     <= '1';
                when CSR_DPC      => csr_dpc_we      <= '1';
                when CSR_DM_DATA0 => csr_dm_data0_we <= '1';
                when others       =>
            end case;
        end process;

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                csr_mie_q.meie <= '0';
                csr_mie_q.mtie <= '0';
            elsif rising_edge(clk_i) then
                if csr_mie_we = '1' and csr_write_en = '1' then
                    csr_mie_q.meie <= csr_write_data(11);
                    csr_mie_q.mtie <= csr_write_data(7);
                end if;
            end if;
        end process;
        csr_q.mie <= (31 downto 12 => '0') & csr_mie_q.meie & (10 downto 8 => '0') & csr_mie_q.mtie & (6 downto 0 => '0');

        mcause_nxt <=
               (CSR_MCAUSE_ILLEGAL_INSTRUCTION                                         and (31 downto 0 => illegal_instr_q          and bool_to_sl(C_CATCH_ILLEGAL)))
            or (CSR_MCAUSE_MACHINE_ECALL                                               and (31 downto 0 => ecall_q                  and bool_to_sl(C_IMPL_ECALL)))
            or (CSR_MCAUSE_INSTRUCTION_ADDRESS_MISALIGNED                              and (31 downto 0 => misaligned_instruction_q and bool_to_sl(C_CATCH_MISALIGNED_INSTRUCTION)))
            or (CSR_MCAUSE_BREAKPOINT                                                  and (31 downto 0 => ebreak_q                 and bool_to_sl(C_IMPL_EBREAK)))
            or (CSR_MCAUSE_LOAD_ADDRESS_MISALIGNED                                     and (31 downto 0 => misaligned_load_q        and bool_to_sl(C_CATCH_MISALIGNED_LOAD_STORE)))
            or (CSR_MCAUSE_LOAD_ADDRESS_MISALIGNED                                     and (31 downto 0 => misaligned_store_q       and bool_to_sl(C_CATCH_MISALIGNED_LOAD_STORE)))
            or (CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT                                  and (31 downto 0 => external_interrupt_q     and not exception_q))
            or (CSR_MCAUSE_MACHINE_TIMER_INTERRUPT                                     and (31 downto 0 => timer_interrupt_q        and not exception_q))
            ;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if exception_q = '1' or interrupt_q = '1' then
                    csr_q.mcause <= mcause_nxt;
                elsif csr_mcause_we = '1' and csr_write_en = '1' then
                    csr_q.mcause <= csr_write_data(31) & (30 downto 6 => '0') & csr_write_data(5 downto 0);
                end if;
                if exception_q = '1' or interrupt_q = '1' then
                    csr_q.mepc <= epc_nxt(31 downto 2) & "00";
                    if G_EXTENSION_C = TRUE then
                        csr_q.mepc(1) <= epc_nxt(1);
                    end if;
                elsif csr_mepc_we = '1' and csr_write_en = '1' then
                    csr_q.mepc <= csr_write_data(31 downto 2) & "00";
                    if G_EXTENSION_C = TRUE then
                        csr_q.mepc(1) <= csr_write_data(1);
                    end if;
                end if;
                if csr_mscratch_we = '1' and csr_write_en = '1' then
                    csr_q.mscratch <= csr_write_data;
                end if;
                if csr_mtvec_we = '1' and csr_write_en = '1' then
                    csr_q.mtvec <= csr_write_data;
                end if;
            end if;
        end process;

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                csr_mstatus_q.mpie <= '0';
                csr_mstatus_q.mie <= '0';
            elsif rising_edge(clk_i) then
                if trap_entry = '1' and trap_exit = '0' then
                    csr_mstatus_q.mpie <= csr_mstatus_q.mie;
                    -- mstatus.mie = 0
                    csr_mstatus_q.mie  <= '0';
                elsif trap_entry = '0' and trap_exit = '1' then
                    -- mstatus.mie = mstatus.mpie
                    csr_mstatus_q.mie  <= csr_mstatus_q.mpie;
                    csr_mstatus_q.mpie <= '1';
                elsif csr_mstatus_we = '1' and csr_write_en = '1' then
                    csr_mstatus_q.mie  <= csr_write_data(3);
                    csr_mstatus_q.mpie <= csr_write_data(7);
                end if;
            end if;
        end process;
        csr_mstatus_q.mpp <= "11";
        csr_q.mstatus <= (31 downto 13 => '0') & csr_mstatus_q.mpp & (10 downto 8 => '0') & csr_mstatus_q.mpie & (6 downto 4 => '0') & csr_mstatus_q.mie & (2 downto 0 => '0');

        gen_mtval: if C_IMPL_EBREAK = TRUE or C_CATCH_ILLEGAL = TRUE or C_CATCH_MISALIGNED_INSTRUCTION = TRUE or C_CATCH_MISALIGNED_LOAD_STORE = TRUE generate
            signal mtval_nxt : std_logic_vector(31 downto 0);
        begin
            mtval_nxt <=
                   (memory_pc_q(31 downto 2) & "00" and (31 downto 0 =>     ebreak_q                                  and bool_to_sl(C_IMPL_EBREAK and not G_EXTENSION_C)))
                or (memory_pc_q(31 downto 1) & '0'  and (31 downto 0 =>     ebreak_q                                  and bool_to_sl(C_IMPL_EBREAK and     G_EXTENSION_C)))
                or (instr_dat_q                     and (31 downto 0 =>     illegal_instr_q                           and bool_to_sl(C_CATCH_ILLEGAL)))
                or (memory_alu_b_res_q              and (31 downto 0 =>    (misaligned_instruction_q                  and bool_to_sl(C_CATCH_MISALIGNED_INSTRUCTION))
                                                                        or (misaligned_load_q                         and bool_to_sl(C_CATCH_MISALIGNED_LOAD_STORE))
                                                                        or (misaligned_store_q                        and bool_to_sl(C_CATCH_MISALIGNED_LOAD_STORE))))
                ;

            process (clk_i)
            begin
                if rising_edge(clk_i) then
                    if exception_q = '1' or interrupt_q = '1' then
                        csr_q.mtval <= mtval_nxt;
                    end if;
                end if;
            end process;
        end generate gen_mtval;

        gen_no_mtval: if not (C_IMPL_EBREAK = TRUE or C_CATCH_ILLEGAL = TRUE or C_CATCH_MISALIGNED_INSTRUCTION = TRUE or C_CATCH_MISALIGNED_LOAD_STORE = TRUE) generate
            csr_q.mtval <= (others => '0');
        end generate gen_no_mtval;

        trap_entry_vect <= csr_q.mtvec(31 downto 2) & "00";
        trap_exit_vect  <= csr_q.mepc;

        -- debug module
        gen_debug_module: if G_DEBUG_MODULE = TRUE generate
            signal dcsr_debugver : std_logic_vector(3 downto 0);
            signal dcsr_cause_nxt, dcsr_cause_q : std_logic_vector(2 downto 0);
            signal dm_data0_wdata : std_logic_vector(31 downto 0);
            signal dm_data0_we : std_logic;
            signal depc_nxt : std_logic_vector(31 downto 0);
            signal csr_debug_we : std_logic;
        begin
            dcsr_cause_nxt <=
                   (std_logic_vector(to_unsigned(3, 3)) and (2 downto 0 => debug_haltreq_q))
                or (std_logic_vector(to_unsigned(1, 3)) and (2 downto 0 => debug_breakpoint_q))
                or (std_logic_vector(to_unsigned(4, 3)) and (2 downto 0 => debug_step_q))
                ;

            csr_debug_we <= debug_mode_q and csr_write_en;

            process (clk_i, arst_i)
            begin
                if arst_i = '1' then
                    debug_mode_q <= '0';
                    dcsr_ebreakm_q <= '0';
                    dcsr_stepie_q <= '0';
                    dcsr_cause_q <= (others => '0');
                    dcsr_step_q <= '0';
                elsif rising_edge(clk_i) then
                    if debug_trap_entry = '1' or debug_trap_exit = '1' then
                        debug_mode_q <= debug_trap_entry;
                    end if;
                    if debug_trap_entry = '1' then
                        dcsr_cause_q <= dcsr_cause_nxt;
                    elsif csr_dcsr_we = '1' and csr_debug_we = '1' then
                        dcsr_cause_q <= csr_write_data(8 downto 6);
                    end if;
                    if csr_dcsr_we = '1' and csr_debug_we = '1' then
                        dcsr_ebreakm_q <= csr_write_data(15);
                        dcsr_stepie_q <= csr_write_data(11);
                        dcsr_step_q <= csr_write_data(2);
                    end if;
                end if;
            end process;

            depc_nxt <=
                   (memory_pc_q        and (31 downto 0 =>      debug_exc_q))
                or (memory_alu_b_res_q and (31 downto 0 => (not debug_exc_q and debug_int_q) and     memory_branch_q and not (trap_entry or trap_exit)))
                or (execute_pc_q       and (31 downto 0 => (not debug_exc_q and debug_int_q) and not memory_branch_q and not (trap_entry or trap_exit)))
                or (trap_entry_vect    and (31 downto 0 => (not debug_exc_q and debug_int_q) and                              trap_entry              ))
                or (trap_exit_vect     and (31 downto 0 => (not debug_exc_q and debug_int_q) and                                            trap_exit ))
                ;

            process (clk_i)
            begin
                if rising_edge(clk_i) then
                    if debug_trap_entry = '1' then
                        csr_q.dpc <= depc_nxt(31 downto 2) & "00";
                        if G_EXTENSION_C = TRUE then
                            csr_q.dpc(1) <= depc_nxt(1);
                        end if;
                    elsif csr_dpc_we = '1' and csr_debug_we = '1' then
                        csr_q.dpc <= csr_write_data(31 downto 2) & "00";
                        if G_EXTENSION_C = TRUE then
                            csr_q.dpc(1) <= csr_write_data(1);
                        end if;
                    end if;
                    if dm_data0_we = '1' then
                        csr_q.dm_data0 <= dm_data0_wdata;
                    elsif csr_dm_data0_we = '1' and csr_debug_we = '1' then
                        csr_q.dm_data0 <= csr_write_data;
                    end if;
                end if;
            end process;

            dcsr_debugver <= x"4";

            csr_q.dcsr(31 downto 28) <= dcsr_debugver;
            csr_q.dcsr(27 downto 16) <= (others => '0');
            csr_q.dcsr(15) <= dcsr_ebreakm_q;
            csr_q.dcsr(14 downto 12) <= (others => '0');
            csr_q.dcsr(11) <= dcsr_stepie_q;
            csr_q.dcsr(10 downto 9) <= (others => '0');
            csr_q.dcsr(8 downto 6) <= dcsr_cause_q;
            csr_q.dcsr(5 downto 3) <= (others => '0');
            csr_q.dcsr(2) <= dcsr_step_q;
            csr_q.dcsr(1 downto 0) <= (others => '0');

            u_debug_module : entity work.debug_module
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                debug_mode_i => debug_mode_q,
                debug_reset_o => debug_reset,
                debug_haltreq_o => debug_haltreq,
                debug_adr_i => debug_cmd_adr_i,
                debug_vld_i => debug_cmd_vld_i,
                debug_we_i => debug_cmd_we_i,
                debug_dat_i => debug_cmd_dat_i,
                debug_dat_o => debug_rsp_dat_o,
                debug_vld_o => debug_rsp_vld_o,
                debug_rdy_o => debug_cmd_rdy_o,
                enable_i => fetch_enable,
                instr_cmd_valid_i => debug_instr_cmd_vld,
                instr_cmd_ready_o => debug_instr_cmd_rdy,
                instr_rsp_data_o => debug_instr_rsp_dat,
                instr_rsp_valid_o => debug_instr_rsp_vld,
                csr_data0_dat_o => dm_data0_wdata,
                csr_data0_vld_o => dm_data0_we,
                csr_data0_dat_i => csr_q.dm_data0,
                ebreak_i => ebreak_q,
                dret_i => dret_q
            );

            process (clk_i, arst_i)
            begin
                if arst_i = '1' then
                    debug_mode_sel_q <= '0';
                elsif rising_edge(clk_i) then
                    if fetch_pending_cnt_q = 0 then
                        debug_mode_sel_q <= debug_mode_q;
                    end if;
                end if;
            end process;
        end generate gen_debug_module;

        gen_no_debug_module: if G_DEBUG_MODULE = FALSE generate
            dcsr_step_q      <= '0';
            dcsr_stepie_q    <= '0';
            dcsr_ebreakm_q   <= '0';
        end generate gen_no_debug_module;

        csr_trap_entry <= trap_entry;
        csr_trap_exit <= trap_exit;
        csr_trap_entry_vect <= trap_entry_vect;
        csr_trap_exit_vect <= trap_exit_vect;
        csr_trap_exception <= exception_q;
        csr_trap_interrupt <= interrupt_q;
        csr_trap_exception_pc <= epc_nxt;
    end generate gen_csr;

    gen_no_csr: if G_EXTENSION_ZICSR = FALSE generate
        csr_read_data <= (others => '-');
        csr_load_pc   <= '0';
        csr_target_pc <= (others => '-');
        csr_trap_entry <= '0';
        csr_trap_exit  <= '0';
    end generate gen_no_csr;
        
    gen_no_debug_module: if G_EXTENSION_ZICSR = FALSE or G_DEBUG_MODULE = FALSE generate
        debug_mode_q     <= '0';
        debug_reset      <= '0';
        debug_mode_sel_q <= '0';
        debug_cmd_rdy_o  <= '0';
        debug_rsp_vld_o  <= '0';
        debug_rsp_dat_o  <= (others => '0');
    end generate gen_no_debug_module;


-- cpu checker
    gen_verif: if G_VERIFICATION = TRUE generate
    begin
        u_cpu_checker : entity work.cpu_checker
            generic map (
                G_EXTENSION_C => FALSE,
                G_EXTENSION_ZICSR => FALSE
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                decode_valid_i => decode_valid_q,
                decode_instr_i => decode_instr_dat_q,
                decode_instr_compress_i => decode_instr_rvc_q,
                decode_rs1_dat_i => decode_rs1_dat,
                decode_rs2_dat_i => decode_rs2_dat,
                decode_pc_i => decode_pc_q,
                execute_enable_i => execute_enable,
                execute_flush_i => execute_flush,
                memory_enable_i => memory_enable,
                memory_flush_i => memory_flush,
                writeback_enable_i => writeback_enable,
                writeback_flush_i => writeback_flush,
                mem_cmd_adr_i => data_cmd_adr,
                mem_cmd_dat_i => data_cmd_dat,
                mem_cmd_vld_i => data_cmd_vld,
                mem_cmd_we_i => data_cmd_we,
                mem_rsp_dat_i => data_rsp_dat_i,
                mem_rsp_vld_i => data_rsp_vld_i,
                fetch_enable_i => fetch_enable,
                fetch_load_pc_i => fetch_load_pc_en,
                fetch_target_pc_i => fetch_target_pc,
                trap_entry_i => csr_trap_entry,
                trap_exit_i => csr_trap_exit,
                trap_entry_vect_i => csr_trap_entry_vect,
                trap_exit_vect_i => csr_trap_exit_vect,
                trap_exception_i => csr_trap_exception,
                trap_interrupt_i => csr_trap_interrupt,
                trap_exception_pc_i => csr_trap_exception_pc,
                regfile_rd_we_i => regfile_rd_we,
                regfile_rd_dat_i => regfile_rd_dat,
                regfile_rd_adr_i => regfile_rd_adr
            );
    end generate gen_verif;

end architecture rtl;
