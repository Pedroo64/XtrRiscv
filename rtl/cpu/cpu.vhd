library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;
use work.vhdl_utils.all;

entity cpu is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_EXECUTE_BYPASS : boolean := FALSE;
        G_MEMORY_BYPASS : boolean := FALSE;
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_REGFILE_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE;
        G_EXTENSION_M : boolean := FALSE;
        G_EXTENSION_C : boolean := FALSE;
        G_EXTENSION_ZICSR : boolean := FALSE;
        G_DEBUG_MODULE : boolean := FALSE;
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
        debug_cmd_rdy_o : out std_logic := '0';
        debug_rsp_vld_o : out std_logic := '0';
        debug_rsp_dat_o : out std_logic_vector(31 downto 0);
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic
    );
end entity cpu;

architecture rtl of cpu is
    -- types
    type alu_a_op_t is (ALU_OP_ADD, ALU_OP_SUB, ALU_OP_AND, ALU_OP_OR, ALU_OP_XOR, ALU_OP_SLT, ALU_OP_SLTU);
    -- global
    signal booted_q : std_logic;
    -- fetch
    signal fetch_enable, fetch_flush, fetch_pc_en, fetch_load_pc_en : std_logic;
    signal fetch_pc_q, fetch_nxt_pc, fetch_target_pc : std_logic_vector(31 downto 0);
    signal fetch_instr_dat_q, fetch_instr_dat : std_logic_vector(31 downto 0);
    signal fetch_valid_q, fetch_valid : std_logic;
    signal fetch_rs1_adr, fetch_rs2_adr : std_logic_vector(4 downto 0);
    -- decode
    signal decode_enable, decode_flush, decode_valid_q : std_logic;
    signal decode_instr_dat_q, decode_pc_q, decode_nxt_pc, decode_pc_incr : std_logic_vector(31 downto 0);
    signal decode_opcode : std_logic_vector(6 downto 0);
    signal decode_funct3 : std_logic_vector(2 downto 0);
    signal decode_funct7 : std_logic_vector(6 downto 0);
    signal decode_jump, decode_branch : std_logic;
    signal decode_rs1_en, decode_rs2_en, decode_rd_we, decode_rd_is_zero : std_logic;
    signal decode_rs1_adr, decode_rs2_adr, decode_rd_adr : std_logic_vector(4 downto 0);
    signal decode_rs1_dat, decode_rs2_dat : std_logic_vector(31 downto 0);
    signal decode_imm_i, decode_imm_s, decode_imm_b, decode_imm_u, decode_imm_j : std_logic_vector(31 downto 0);
    signal decode_alu_a_src1, decode_alu_a_src2 : std_logic_vector(31 downto 0);
    signal decode_alu_a_op : alu_a_op_t;
    signal decode_alu_a_res_sel : std_logic;
    signal decode_alu_b_src1, decode_alu_b_src2 : std_logic_vector(31 downto 0);
    signal decode_lsu_valid, decode_lsu_load, decode_lsu_store : std_logic;
    -- execute
    signal execute_enable, execute_flush, execute_valid_q, execute_rd_we_q, execute_lsu_valid_q, execute_load_q, execute_store_q: std_logic;
    signal execute_rd_adr_q : std_logic_vector(4 downto 0);
    signal execute_funct3_q : std_logic_vector(2 downto 0);
    signal execute_funct7_q : std_logic_vector(6 downto 0);
    signal execute_jump_q, execute_branch_q, execute_branch : std_logic;
    signal execute_alu_a_src1_q, execute_alu_a_src2_q, execute_alu_a_r, execute_alu_a_res : std_logic_vector(31 downto 0);
    signal execute_alu_a_op_q : alu_a_op_t;
    signal execute_alu_a_res_sel_q : std_logic;
    signal execute_alu_b_src1_q, execute_alu_b_src2_q, execute_alu_b_res : std_logic_vector(31 downto 0);
    signal execute_shifter_res : std_logic_vector(31 downto 0);
    -- memory
    signal memory_enable, memory_flush, memory_valid_q, memory_rd_we_q : std_logic;
    signal memory_funct3_q : std_logic_vector(2 downto 0);
    signal memory_rd_adr_q : std_logic_vector(4 downto 0);
    signal memory_alu_a_res_q, memory_alu_b_res_q : std_logic_vector(31 downto 0);
    signal memory_branch_q, memory_load_q : std_logic;
    signal memory_mem_dat : std_logic_vector(31 downto 0);
    -- writeback
    signal writeback_enable, writeback_flush, writeback_valid_q, writeback_rd_we_q : std_logic;
    signal writeback_funct3_q : std_logic_vector(2 downto 0);
    signal writeback_rd_adr_q : std_logic_vector(4 downto 0);
    signal writeback_alu_a_res_q, writeback_mem_dat_q, writeback_mem_dat, writeback_rd_dat : std_logic_vector(31 downto 0);
    signal writeback_load_q : std_logic;
    signal writeback_mem_adr_q : std_logic_vector(1 downto 0);
    -- branch
    signal branch_load_pc : std_logic;
    signal branch_target_pc : std_logic_vector(31 downto 0);
    -- ctl
    signal ctl_fetch_stall, ctl_decode_stall, ctl_execute_stall, ctl_memory_stall, ctl_writeback_stall : std_logic;
    signal ctl_decode_execute_rs1_match, ctl_decode_memory_rs1_match, ctl_decode_writeback_rs1_match, ctl_decode_regfile_rs1_match : std_logic;
    signal ctl_decode_execute_rs2_match, ctl_decode_memory_rs2_match, ctl_decode_writeback_rs2_match, ctl_decode_regfile_rs2_match : std_logic;
    signal ctl_decode_execute_rs1_hazard, ctl_decode_memory_rs1_hazard, ctl_decode_writeback_rs1_hazard, ctl_decode_regfile_rs1_hazard : std_logic;
    signal ctl_decode_execute_rs2_hazard, ctl_decode_memory_rs2_hazard, ctl_decode_writeback_rs2_hazard, ctl_decode_regfile_rs2_hazard : std_logic;
    signal ctl_decode_execute_rs1_forward, ctl_decode_memory_rs1_forward, ctl_decode_writeback_rs1_forward, ctl_decode_regfile_rs1_forward : std_logic;
    signal ctl_decode_execute_rs2_forward, ctl_decode_memory_rs2_forward, ctl_decode_writeback_rs2_forward, ctl_decode_regfile_rs2_forward : std_logic;
    -- regfile
    signal regfile_rs1_en, regfile_rs2_en, regfile_rd_we, regfile_rd_we_q : std_logic;
    signal regfile_rs1_adr, regfile_rs2_adr, regfile_rd_adr, regfile_rd_adr_q : std_logic_vector(4 downto 0);
    signal regfile_rs1_dat, regfile_rs2_dat, regfile_rd_dat, regfile_rd_dat_q : std_logic_vector(31 downto 0);
    -- memory interface
    signal data_cmd_adr, data_cmd_dat : std_logic_vector(31 downto 0);
    signal data_cmd_vld, data_cmd_we : std_logic;
    signal data_cmd_siz : std_logic_vector(1 downto 0);
begin

-- Fetch stage
    fetch_load_pc_en <= branch_load_pc;
    fetch_target_pc  <= branch_target_pc;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            booted_q <= '0';
        elsif rising_edge(clk_i) then
            booted_q <= not srst_i;
        end if;
    end process;

    fetch_nxt_pc <=
        fetch_target_pc when fetch_load_pc_en = '1' else
        std_logic_vector(unsigned(fetch_pc_q) + 4);

    fetch_pc_en <= fetch_enable and (fetch_load_pc_en or instr_cmd_rdy_i);

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if fetch_pc_en = '1' then
                fetch_pc_q <= fetch_nxt_pc;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if instr_rsp_vld_i = '1' then
                fetch_instr_dat_q <= instr_rsp_dat_i;
            end if;
        end if;
    end process;

    fetch_instr_dat <= instr_rsp_dat_i when instr_rsp_vld_i = '1' else fetch_instr_dat_q;
    fetch_rs1_adr <= fetch_instr_dat(19 downto 15);
    fetch_rs2_adr <= fetch_instr_dat(24 downto 20);

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            fetch_valid_q <= '0';
        elsif rising_edge(clk_i) then
            if fetch_enable = '1' then
                fetch_valid_q <= not fetch_flush and booted_q;
            end if;
        end if;
    end process;

    instr_cmd_adr_o <= fetch_pc_q;
    instr_cmd_vld_o <= booted_q and fetch_enable;

-- Decode stage
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            decode_valid_q <= '0';
        elsif rising_edge(clk_i) then
            if decode_enable = '1' then
                decode_valid_q <= fetch_valid_q and not decode_flush;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if decode_enable = '1' then
                decode_instr_dat_q <= fetch_instr_dat;
                decode_pc_q <= decode_nxt_pc;
            end if;
        end if;
    end process;

    decode_pc_incr <= std_logic_vector(to_unsigned(4, decode_pc_incr'length));

    decode_nxt_pc <=
        branch_target_pc when branch_load_pc = '1' else
        std_logic_vector(unsigned(decode_pc_q) + unsigned(decode_pc_incr)) when decode_valid_q = '1' else
        decode_pc_q;

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

    process (decode_opcode, decode_funct3)
    begin
        decode_jump <= '0';
        decode_branch <= '0';
        decode_lsu_load <= '0';
        decode_lsu_store <= '0';
        decode_alu_a_res_sel <= '0';
        decode_lsu_valid <= '0';
        case decode_opcode is
            when RV32I_OP_LUI     =>
            when RV32I_OP_AUIPC   =>
            when RV32I_OP_JAL     => decode_jump <= '1';
            when RV32I_OP_JALR    => decode_jump <= '1';
            when RV32I_OP_BRANCH  => decode_branch <= '1';
            when RV32I_OP_LOAD    => decode_lsu_load <= '1'; decode_lsu_valid <= '1';
            when RV32I_OP_STORE   => decode_lsu_store <= '1'; decode_lsu_valid <= '1';
            when RV32I_OP_REG_IMM => if decode_funct3 = "001" or decode_funct3 = "101" then decode_alu_a_res_sel <= '1'; end if;
            when RV32I_OP_REG_REG => if decode_funct3 = "001" or decode_funct3 = "101" then decode_alu_a_res_sel <= '1'; end if;
            when RV32I_OP_FENCE   =>
            when RV32I_OP_SYS     =>
            when others =>
        end case;
    end process;

    process (decode_opcode, decode_funct3, decode_funct7)
    begin
        decode_alu_a_op <= ALU_OP_ADD;
        case decode_opcode is
            when RV32I_OP_REG_IMM =>
                case decode_funct3 is
                    when RV32I_FN3_ADD  =>
                    when RV32I_FN3_SL   =>
                    when RV32I_FN3_SLT  => decode_alu_a_op <= ALU_OP_SLT;
                    when RV32I_FN3_SLTU => decode_alu_a_op <= ALU_OP_SLTU;
                    when RV32I_FN3_XOR  => decode_alu_a_op <= ALU_OP_XOR;
                    when RV32I_FN3_SR   =>
                    when RV32I_FN3_OR   => decode_alu_a_op <= ALU_OP_OR;
                    when RV32I_FN3_AND  => decode_alu_a_op <= ALU_OP_AND;
                    when others =>
                end case;
            when RV32I_OP_REG_REG =>
                case decode_funct3 is
                    when RV32I_FN3_ADD  => if decode_funct7 = RV32M_FN7_SUB then decode_alu_a_op <= ALU_OP_SUB; end if;
                    when RV32I_FN3_SL   =>
                    when RV32I_FN3_SLT  => decode_alu_a_op <= ALU_OP_SLT;
                    when RV32I_FN3_SLTU => decode_alu_a_op <= ALU_OP_SLTU;
                    when RV32I_FN3_XOR  => decode_alu_a_op <= ALU_OP_XOR;
                    when RV32I_FN3_SR   =>
                    when RV32I_FN3_OR   => decode_alu_a_op <= ALU_OP_OR;
                    when RV32I_FN3_AND  => decode_alu_a_op <= ALU_OP_AND;
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
            when RV32I_OP_SYS     => decode_rs1_en <= '1'; decode_rs2_en <= '0'; decode_rd_we <= '1';
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
                execute_valid_q <= decode_valid_q and not execute_flush;
                execute_rd_we_q <= decode_valid_q and decode_rd_we and not decode_rd_is_zero and not execute_flush;
                execute_lsu_valid_q <= decode_valid_q and decode_lsu_valid and not execute_flush;
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
                execute_alu_a_res_sel_q <= decode_alu_a_res_sel;
                execute_alu_b_src1_q <= decode_alu_b_src1;
                execute_alu_b_src2_q <= decode_alu_b_src2;
                execute_funct3_q <= decode_funct3;
                execute_funct7_q <= decode_funct7;
                execute_jump_q <= decode_jump;
                execute_branch_q <= decode_branch;
                execute_load_q  <= decode_lsu_load;
                execute_store_q <= decode_lsu_store;
            end if;
        end if;
    end process;

    process (execute_alu_a_op_q, execute_alu_a_src1_q, execute_alu_a_src2_q)
    begin
        execute_alu_a_r <= (others => 'X');
        case execute_alu_a_op_q is
            when ALU_OP_ADD  => execute_alu_a_r <= std_logic_vector(unsigned(execute_alu_a_src1_q) + unsigned(execute_alu_a_src2_q));
            when ALU_OP_SUB  => execute_alu_a_r <= std_logic_vector(unsigned(execute_alu_a_src1_q) - unsigned(execute_alu_a_src2_q));
            when ALU_OP_AND  => execute_alu_a_r <= execute_alu_a_src1_q and execute_alu_a_src2_q;
            when ALU_OP_OR   => execute_alu_a_r <= execute_alu_a_src1_q or  execute_alu_a_src2_q;
            when ALU_OP_XOR  => execute_alu_a_r <= execute_alu_a_src1_q xor execute_alu_a_src2_q;
            when ALU_OP_SLT  => if   signed(execute_alu_a_src1_q) <   signed(execute_alu_a_src2_q) then execute_alu_a_r <= std_logic_vector(to_unsigned(1, execute_alu_a_r'length)); else execute_alu_a_r <= std_logic_vector(to_unsigned(0, execute_alu_a_r'length)); end if;
            when ALU_OP_SLTU => if unsigned(execute_alu_a_src1_q) < unsigned(execute_alu_a_src2_q) then execute_alu_a_r <= std_logic_vector(to_unsigned(1, execute_alu_a_r'length)); else execute_alu_a_r <= std_logic_vector(to_unsigned(0, execute_alu_a_r'length)); end if;
            when others =>
        end case;
    end process;

    execute_alu_b_res <= std_logic_vector(unsigned(execute_alu_b_src1_q) + unsigned(execute_alu_b_src2_q));

    process (execute_jump_q, execute_branch_q, execute_funct3_q, execute_alu_a_src1_q, execute_alu_a_src2_q)
    begin
        execute_branch <= '0';
        if execute_jump_q = '1' then
            execute_branch <= '1';
        elsif execute_branch_q = '1' then
            case execute_funct3_q is
                when RV32I_FN3_BEQ  => if          execute_alu_a_src1_q  =           execute_alu_a_src2_q  then execute_branch <= '1'; end if;
                when RV32I_FN3_BNE  => if          execute_alu_a_src1_q  /=          execute_alu_a_src2_q  then execute_branch <= '1'; end if;
                when RV32I_FN3_BLT  => if   signed(execute_alu_a_src1_q) <    signed(execute_alu_a_src2_q) then execute_branch <= '1'; end if;
                when RV32I_FN3_BGE  => if   signed(execute_alu_a_src1_q) >=   signed(execute_alu_a_src2_q) then execute_branch <= '1'; end if;
                when RV32I_FN3_BLTU => if unsigned(execute_alu_a_src1_q) <  unsigned(execute_alu_a_src2_q) then execute_branch <= '1'; end if;
                when RV32I_FN3_BGEU => if unsigned(execute_alu_a_src1_q) >= unsigned(execute_alu_a_src2_q) then execute_branch <= '1'; end if;
                when others =>
            end case;
        end if;
    end process;

    process (execute_funct3_q, execute_funct7_q, execute_alu_a_src1_q, execute_alu_a_src2_q)
    begin
        if execute_funct3_q(2) = '0' then
            execute_shifter_res <= std_logic_vector(shift_left( unsigned(execute_alu_a_src1_q), to_integer(unsigned(execute_alu_a_src2_q(4 downto 0)))));
        elsif execute_funct3_q(2) = '1' and execute_funct7_q(5) = '0' then
            execute_shifter_res <= std_logic_vector(shift_right(unsigned(execute_alu_a_src1_q), to_integer(unsigned(execute_alu_a_src2_q(4 downto 0)))));
        elsif execute_funct3_q(2) = '1' and execute_funct7_q(5) = '1' then
            execute_shifter_res <= std_logic_vector(shift_right(  signed(execute_alu_a_src1_q), to_integer(unsigned(execute_alu_a_src2_q(4 downto 0)))));
        else
            execute_shifter_res <= (others => 'X');
        end if;
    end process;

    execute_alu_a_res <= execute_shifter_res when execute_alu_a_res_sel_q = '1' else execute_alu_a_r;

    data_cmd_adr <= execute_alu_b_res;
    process (execute_funct3_q, execute_alu_a_src2_q)
    begin
        case execute_funct3_q(1 downto 0) is
            when RV32I_FN3_SB => data_cmd_dat <= execute_alu_a_src2_q(7 downto 0) & execute_alu_a_src2_q(7 downto 0) & execute_alu_a_src2_q(7 downto 0) & execute_alu_a_src2_q(7 downto 0);
            when RV32I_FN3_SH => data_cmd_dat <= execute_alu_a_src2_q(15 downto 0) & execute_alu_a_src2_q(15 downto 0);
            when RV32I_FN3_SW => data_cmd_dat <= execute_alu_a_src2_q;
            when others => data_cmd_dat <= (others => 'X');
        end case;
    end process;


    data_cmd_vld <= execute_lsu_valid_q and memory_enable and not branch_load_pc;
    data_cmd_we  <= execute_store_q;
    data_cmd_siz <= execute_funct3_q(1 downto 0);

    data_cmd_adr_o <= data_cmd_adr;
    data_cmd_vld_o <= data_cmd_vld;
    data_cmd_we_o <= data_cmd_we;
    data_cmd_dat_o <= data_cmd_dat;
    data_cmd_siz_o <= data_cmd_siz;

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
            end if;
        end if;
    end process;

    memory_mem_dat <= data_rsp_dat_i;

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
                writeback_alu_a_res_q <= memory_alu_a_res_q;
                writeback_mem_dat_q <= memory_mem_dat;
                writeback_mem_adr_q <= memory_alu_b_res_q(1 downto 0);
                writeback_load_q <= memory_load_q;
            end if;
        end if;
    end process;

    process (writeback_funct3_q, writeback_mem_adr_q, writeback_mem_dat_q)
    begin
        writeback_mem_dat <= (others => 'X');
        case writeback_funct3_q(1 downto 0) is
            when RV32I_FN3_LB =>
                case writeback_mem_adr_q is
                    when "00" => writeback_mem_dat <= (31 downto 8 => not writeback_funct3_q(2) and writeback_mem_dat_q(07)) & writeback_mem_dat_q(07 downto 00);
                    when "01" => writeback_mem_dat <= (31 downto 8 => not writeback_funct3_q(2) and writeback_mem_dat_q(15)) & writeback_mem_dat_q(15 downto 08);
                    when "10" => writeback_mem_dat <= (31 downto 8 => not writeback_funct3_q(2) and writeback_mem_dat_q(23)) & writeback_mem_dat_q(23 downto 16);
                    when "11" => writeback_mem_dat <= (31 downto 8 => not writeback_funct3_q(2) and writeback_mem_dat_q(31)) & writeback_mem_dat_q(31 downto 24);
                    when others =>
                end case;
            when RV32I_FN3_LH =>
                if writeback_mem_adr_q(1) = '0' then
                    writeback_mem_dat <= (31 downto 16 => not writeback_funct3_q(2) and writeback_mem_dat_q(15)) & writeback_mem_dat_q(15 downto 00);
                else
                    writeback_mem_dat <= (31 downto 16 => not writeback_funct3_q(2) and writeback_mem_dat_q(31)) & writeback_mem_dat_q(31 downto 16);
                end if;
            when RV32I_FN3_LW =>
                writeback_mem_dat <= writeback_mem_dat_q;
            when others =>
        end case;
    end process;

    writeback_rd_dat <= writeback_mem_dat when writeback_load_q = '1' else writeback_alu_a_res_q;

-- Branch
    branch_load_pc   <= memory_branch_q or not booted_q;
    branch_target_pc <=
        G_BOOT_ADDRESS when booted_q = '0' else
        memory_alu_b_res_q;

-- Regfile
    regfile_rs1_adr <= decode_rs1_adr when decode_enable = '0' else fetch_rs1_adr;
    regfile_rs1_en  <= '1';
    regfile_rs2_adr <= decode_rs2_adr when decode_enable = '0' else fetch_rs2_adr;
    regfile_rs2_en  <= '1';
    regfile_rd_adr <= writeback_rd_adr_q;
    regfile_rd_dat <= writeback_rd_dat;
    regfile_rd_we  <= writeback_rd_we_q;

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

    ctl_decode_execute_rs1_forward   <= '1' when execute_rd_we_q = '1' and ctl_decode_execute_rs1_match = '1' and G_EXECUTE_BYPASS = TRUE else '0';
    ctl_decode_execute_rs2_forward   <= '1' when execute_rd_we_q = '1' and ctl_decode_execute_rs2_match = '1' and G_EXECUTE_BYPASS = TRUE else '0';
    ctl_decode_memory_rs1_forward    <= '1' when memory_rd_we_q = '1' and ctl_decode_memory_rs1_match = '1' and G_MEMORY_BYPASS = TRUE else '0';
    ctl_decode_memory_rs2_forward    <= '1' when memory_rd_we_q = '1' and ctl_decode_memory_rs2_match = '1' and G_MEMORY_BYPASS = TRUE else '0';
    ctl_decode_writeback_rs1_forward <= '1' when writeback_rd_we_q = '1' and ctl_decode_writeback_rs1_match = '1' and G_WRITEBACK_BYPASS = TRUE else '0';
    ctl_decode_writeback_rs2_forward <= '1' when writeback_rd_we_q = '1' and ctl_decode_writeback_rs2_match = '1' and G_WRITEBACK_BYPASS = TRUE else '0';
    ctl_decode_regfile_rs1_forward   <= '1' when regfile_rd_we_q = '1' and ctl_decode_regfile_rs1_match = '1' and G_REGFILE_BYPASS = TRUE else '0';
    ctl_decode_regfile_rs2_forward   <= '1' when regfile_rd_we_q = '1' and ctl_decode_regfile_rs2_match = '1' and G_REGFILE_BYPASS = TRUE else '0';

    decode_rs1_dat <=
        execute_alu_a_res     when ctl_decode_execute_rs1_forward   = '1' else
        memory_alu_a_res_q    when ctl_decode_memory_rs1_forward    = '1' else
        writeback_rd_dat      when ctl_decode_writeback_rs1_forward = '1' else
        regfile_rd_dat_q      when ctl_decode_regfile_rs1_forward   = '1' else
        regfile_rs1_dat;

    decode_rs2_dat <=
        execute_alu_a_res     when ctl_decode_execute_rs2_forward   = '1' else
        memory_alu_a_res_q    when ctl_decode_memory_rs2_forward    = '1' else
        writeback_rd_dat      when ctl_decode_writeback_rs2_forward = '1' else
        regfile_rd_dat_q      when ctl_decode_regfile_rs2_forward   = '1' else
        regfile_rs2_dat;


    ctl_fetch_stall <=
        '1' when ctl_decode_stall = '1' else
        '0';
    ctl_decode_stall <=
        '1' when ctl_execute_stall = '1' else
        '1' when branch_load_pc = '0' and decode_rs1_en = '1' and (ctl_decode_execute_rs1_hazard = '1' or ctl_decode_memory_rs1_hazard = '1' or ctl_decode_writeback_rs1_hazard = '1' or ctl_decode_regfile_rs1_hazard = '1') else
        '1' when branch_load_pc = '0' and decode_rs2_en = '1' and (ctl_decode_execute_rs2_hazard = '1' or ctl_decode_memory_rs2_hazard = '1' or ctl_decode_writeback_rs2_hazard = '1' or ctl_decode_regfile_rs2_hazard = '1') else
        '0';
    ctl_execute_stall <=
        '1' when ctl_memory_stall = '1' else
        '1' when execute_lsu_valid_q = '1' and data_cmd_rdy_i = '0' else -- j @; l/s @delayed_cmd
        '0';
    ctl_memory_stall <=
        '1' when memory_rd_we_q = '1' and memory_load_q = '1' and data_rsp_vld_i = '0' else
        '0';
    ctl_writeback_stall <= '0';

    fetch_flush     <= srst_i or branch_load_pc;
    decode_flush    <= srst_i or branch_load_pc;
    execute_flush   <=
        '1' when srst_i = '1' or branch_load_pc = '1' else
        '1' when decode_rs1_en = '1' and (ctl_decode_execute_rs1_hazard = '1' or ctl_decode_memory_rs1_hazard = '1' or ctl_decode_writeback_rs1_hazard = '1' or ctl_decode_regfile_rs1_hazard = '1') else
        '1' when decode_rs2_en = '1' and (ctl_decode_execute_rs2_hazard = '1' or ctl_decode_memory_rs2_hazard = '1' or ctl_decode_writeback_rs2_hazard = '1' or ctl_decode_regfile_rs2_hazard = '1') else
        '0';
    memory_flush    <=
        '1' when srst_i = '1' or branch_load_pc = '1' else
        '1' when execute_lsu_valid_q = '1' and data_cmd_rdy_i = '0' else
        '0';
    writeback_flush <=
        '1' when srst_i = '1' else
        '1' when memory_rd_we_q = '1' and memory_load_q = '1' and data_rsp_vld_i = '0' else
        '0';

    fetch_enable     <= not ctl_fetch_stall;
    decode_enable    <= not ctl_decode_stall;
    execute_enable   <= not ctl_execute_stall;
    memory_enable    <= not ctl_memory_stall;
    writeback_enable <= not ctl_writeback_stall;


-- cpu checker
    gen_verif: if G_VERIFICATION = TRUE generate
        signal execute_pc_q : std_logic_vector(31 downto 0);
    begin
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if execute_enable = '1' then
                    execute_pc_q <= decode_pc_q;
                end if;
            end if;
        end process;

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
                decode_instr_compress_i => '0',
                decode_rs1_dat_i => decode_rs1_dat,
                decode_rs2_dat_i => decode_rs2_dat,
                execute_enable_i => execute_enable,
                execute_flush_i => execute_flush,
                execute_current_pc_i => execute_pc_q,
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
                csr_exception_entry_i => '0',
                csr_exception_exit_i => '0',
                csr_exception_sync_i => '0',
                csr_exception_async_i => '0',
                csr_mtvec_i => (others => '0'),
                csr_mepc_i => (others => '0'),
                regfile_rd_we_i => regfile_rd_we,
                regfile_rd_dat_i => regfile_rd_dat,
                regfile_rd_adr_i => regfile_rd_adr
            );
    end generate gen_verif;

end architecture rtl;