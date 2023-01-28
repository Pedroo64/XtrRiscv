-- vsim -voptargs=+acc work.tb_xtr_soc(rtl) -gC_INPUT_FILE=D:/Dev/XtrRiscv/soft/bin/test.mem
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;
use work.alu_pkg.all;

entity execute is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        pc_i : in std_logic_vector(31 downto 0);
        opcode_i : in opcode_t;
        immediate_i : in std_logic_vector(31 downto 0);
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        rs2_dat_i : in std_logic_vector(31 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        writeback_valid_o : out std_logic;
        writeback_ready_i : in std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        memory_rd_adr_o : out std_logic_vector(4 downto 0);
        memory_valid_o : out std_logic;
        memory_address_o : out std_logic_vector(31 downto 0);
        memory_data_o : out std_logic_vector(31 downto 0);
        memory_we_o : out std_logic;
        memory_size_o : out std_logic_vector(2 downto 0);
        memory_ready_i : in std_logic;
        csr_rd_adr_o : out std_logic_vector(4 downto 0);
        csr_valid_o : out std_logic;
        csr_address_o : out std_logic_vector(11 downto 0);
        csr_data_o : out std_logic_vector(31 downto 0);
        csr_ready_i : in std_logic;
        exception_valid_i : in std_logic;
        trap_vector_i : in std_logic_vector(31 downto 0);
        exception_pc_i : in std_logic_vector(31 downto 0);
        exception_pc_o : out std_logic_vector(31 downto 0);
        exception_taken_o : out std_logic;
        exception_exit_o : out std_logic;
        mret_o : out std_logic;
        ecall_o : out std_logic;
        ebreak_o : out std_logic;
        ready_o : out std_logic
    );
end entity execute;

architecture rtl of execute is
    signal writeback_valid, memory_valid, csr_valid : std_logic;
    signal latch_writeback_valid, latch_memory_valid, latch_csr_valid : std_logic;
    signal next_stage_ready : std_logic;
    signal load_pc, branch, latch_branch : std_logic;
    signal ecall, ebreak, mret : std_logic;
    signal sync_exception : std_logic;
    signal alu1_op, alu2_op : alu_op_t;
    signal alu1_a, alu1_b, alu1_y : std_logic_vector(31 downto 0);
    signal alu2_a, alu2_b, alu2_y : std_logic_vector(31 downto 0);
    signal alu1_eq, alu1_ge, alu1_lt, alu1_geu, alu1_ltu : std_logic;
    signal branch_pc, next_pc, epc, pc : std_logic_vector(31 downto 0);
    signal rd_dat : std_logic_vector(31 downto 0);
    signal writeback_ready, memory_ready, csr_ready : std_logic;
begin
    
    u_alu_1 : entity work.alu
        port map (
            op_i => alu1_op,
            a_i => alu1_a,
            b_i => alu1_b,
            y_o => alu1_y,
            eq_o => alu1_eq,
            ge_o => alu1_ge,
            lt_o => alu1_lt,
            geu_o => alu1_geu,
            ltu_o => alu1_ltu
        );
    
    alu1_a <= 
        pc_i when (opcode_i.auipc or opcode_i.jal or opcode_i.jalr) = '1' else
        rs1_dat_i when (opcode_i.reg_imm or opcode_i.reg_reg) = '1' else
        (others => '0') when opcode_i.lui = '1' else
        (others => '-');

    alu1_b <= 
        immediate_i when (opcode_i.lui or opcode_i.auipc or opcode_i.reg_imm) = '1' else
        rs2_dat_i when opcode_i.reg_reg = '1' else
        std_logic_vector(to_unsigned(4, alu1_b'length)) when (opcode_i.jal or opcode_i.jalr) = '1' else
        (others => '-');

    process (opcode_i, funct3_i, funct7_i(5))
    begin
        if (opcode_i.lui or opcode_i.auipc or opcode_i.jal or opcode_i.jalr) = '1' then
            alu1_op <= ALU_OP_ADD;
        elsif (opcode_i.reg_imm or opcode_i.reg_reg) = '1' then
            case funct3_i is
                when RV32I_FN3_ADD =>
                    if funct7_i(5) = '1' and opcode_i.reg_reg = '1' then
                        alu1_op <= ALU_OP_SUB;
                    else
                        alu1_op <= ALU_OP_ADD;
                    end if;
                when RV32I_FN3_SL =>
                    alu1_op <= ALU_OP_SLL;
                when RV32I_FN3_SLT =>
                    alu1_op <= ALU_OP_SLT;
                when RV32I_FN3_SLTU =>
                    alu1_op <= ALU_OP_SLTU;
                when RV32I_FN3_XOR =>
                    alu1_op <= ALU_OP_XOR;
                when RV32I_FN3_SR =>
                    if funct7_i(5) = '1' then
                        alu1_op <= ALU_OP_SRA;
                    else
                        alu1_op <= ALU_OP_SRL;
                    end if;
                when RV32I_FN3_OR =>
                    alu1_op <= ALU_OP_OR;
                when RV32I_FN3_AND =>
                    alu1_op <= ALU_OP_AND;
                when others =>
                    alu1_op <= ALU_OP_NOP;
            end case;
        else
            alu1_op <= ALU_OP_NOP;
        end if;
    end process;

    rd_dat <= alu1_y;

    u_alu_2 : entity work.alu
        port map (
            op_i => alu2_op,
            a_i => alu2_a,
            b_i => alu2_b,
            y_o => alu2_y,
            eq_o => open,
            ge_o => open,
            lt_o => open,
            geu_o => open,
            ltu_o => open
        );
    
    alu2_a <= 
        rs1_dat_i when opcode_i.jalr = '1' or opcode_i.load = '1' or opcode_i.store = '1' else
        pc_i when opcode_i.branch = '1' or opcode_i.jal = '1' else
        (others => '-');

    alu2_b <= immediate_i;

    alu2_op <= ALU_OP_ADD;

    next_pc <= 
        exception_pc_i when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "10" else
        trap_vector_i when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1) = '0' else
        trap_vector_i when exception_valid_i = '1' else
        alu2_y;
    
    load_pc <= branch or ecall or ebreak or mret;

    block_branch : block
        signal a, b : unsigned(31 downto 0);
        signal y_eq, y_lt, y_ltu, y_ge, y_geu : std_logic;
    begin
        a <= unsigned(rs1_dat_i);
        b <= unsigned(rs2_dat_i);
        y_eq <= '1' when a = b else '0';
        y_lt <= '1' when signed(a) < signed(b) else '0';
        y_ltu <= '1' when a < b else '0';
        y_ge <= '1' when signed(a) >= signed(b) else '0';
        y_geu <= '1' when a >= b else '0';
        process (opcode_i, funct3_i, y_eq, y_lt, y_ge, y_ltu, y_geu)
        begin
            if (opcode_i.jal or opcode_i.jalr) = '1' then
                branch <= '1';
            elsif opcode_i.branch = '1' then
                case funct3_i is
                    when RV32I_FN3_BEQ =>
                        branch <= y_eq;
                    when RV32I_FN3_BNE =>
                        branch <= not y_eq;
                    when RV32I_FN3_BLT =>
                        branch <= y_lt;
                    when RV32I_FN3_BGE =>
                        branch <= y_ge;
                    when RV32I_FN3_BLTU =>
                        branch <= y_ltu;
                    when RV32I_FN3_BGEU =>
                        branch <= y_geu;
                    when others =>
                        branch <= '0';
                end case;
            else
                branch <= '0';
            end if;
        end process;        
    end block;

    ecall <= enable_i and valid_i when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "00" else '0';
    ebreak <= enable_i and valid_i when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "01" else '0';
    mret <= enable_i and valid_i when opcode_i.sys = '1' and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "10" else '0';
    
    writeback_valid <= 
        valid_i and enable_i when (opcode_i.lui or opcode_i.auipc or opcode_i.jal or opcode_i.jalr or opcode_i.reg_imm or opcode_i.reg_reg) = '1' else 
        '0';

    memory_valid <= 
        valid_i and enable_i when (opcode_i.load or opcode_i.store) = '1' else
        '0';

    csr_valid <= 
        valid_i and enable_i when opcode_i.sys = '1' and unsigned(funct3_i) /= 0 else
        '0';


    block_wb : block
        signal cmd_rdy, cmd_vld : std_logic;
        signal rsp_rdy, rsp_vld : std_logic;
        signal cmd_dat, rsp_dat : std_logic_vector(1 + 5 + 32 - 1 downto 0);
    begin
        cmd_dat <=
            rd_we_i &
            rd_adr_i &
            rd_dat;
        cmd_vld <= writeback_valid;
        writeback_ready <= cmd_rdy;
        u_data_handshake : entity work.data_handshake
            generic map (
                G_DATA_WIDTH => cmd_dat'length
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                command_ready_o => cmd_rdy,
                command_data_i => cmd_dat,
                command_valid_i => cmd_vld,
                response_data_o => rsp_dat,
                response_valid_o => rsp_vld,
                response_ready_i => rsp_rdy
            );
        rd_we_o <= rsp_dat(37);
        rd_dat_o <= rsp_dat(31 downto 0);
        rd_adr_o <= rsp_dat(36 downto 32);
        writeback_valid_o <= rsp_vld;
        rsp_rdy <= writeback_ready_i;
    end block;
    block_mem : block
        signal cmd_rdy, cmd_vld : std_logic;
        signal rsp_rdy, rsp_vld : std_logic;
        signal cmd_dat, rsp_dat : std_logic_vector(1 + 3 + 5 + 32 + 32 - 1 downto 0);
    begin
        cmd_dat <=
            opcode_i.store & 
            funct3_i(2 downto 0) &
            rd_adr_i &
            alu2_y &
            rs2_dat_i;
        cmd_vld <= memory_valid;
        memory_ready <= cmd_rdy;
        u_data_handshake : entity work.data_handshake
            generic map (
                G_DATA_WIDTH => cmd_dat'length
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                command_ready_o => cmd_rdy,
                command_data_i => cmd_dat,
                command_valid_i => cmd_vld,
                response_data_o => rsp_dat,
                response_valid_o => rsp_vld,
                response_ready_i => rsp_rdy
            );
        memory_address_o <= rsp_dat(63 downto 32);
        memory_data_o <= rsp_dat(31 downto 0);
        memory_rd_adr_o <= rsp_dat(68 downto 64);
        memory_size_o <= rsp_dat(71 downto 69);
        memory_we_o <= rsp_dat(72);
        memory_valid_o <= rsp_vld;
        rsp_rdy <= memory_ready_i;
    end block;
    block_csr : block
        signal cmd_rdy, cmd_vld : std_logic;
        signal rsp_rdy, rsp_vld : std_logic;
        signal cmd_dat, rsp_dat : std_logic_vector(3 + 5 + 12 + 32 - 1 downto 0);
        signal csr_dat : std_logic_vector(31 downto 0);
    begin
        csr_dat <= 
            rs1_dat_i when funct3_i(2) = '0' else
            (5 to 31 => '0') & rs1_adr_i;
        cmd_dat <=
            funct3_i &
            rd_adr_i &
            immediate_i(11 downto 0) &
            csr_dat;
        cmd_vld <= csr_valid;
        csr_ready <= cmd_rdy;
        u_data_handshake : entity work.data_handshake
            generic map (
                G_DATA_WIDTH => cmd_dat'length
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                command_ready_o => cmd_rdy,
                command_data_i => cmd_dat,
                command_valid_i => cmd_vld,
                response_data_o => rsp_dat,
                response_valid_o => rsp_vld,
                response_ready_i => rsp_rdy
            );
        csr_address_o <= rsp_dat(43 downto 32);
        csr_data_o <= rsp_dat(31 downto 0);
        csr_rd_adr_o <= rsp_dat(48 downto 44);
        csr_valid_o <= rsp_vld;
        funct3_o <= rsp_dat(51 downto 49);
        rsp_rdy <= memory_ready_i;
    end block;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            ecall_o <= ecall;
            ebreak_o <= ebreak;
            mret_o <= mret;
            sync_exception <= ecall or ebreak;
            load_pc_o <= (enable_i and valid_i and load_pc and next_stage_ready) or exception_valid_i;
            pc_o <= next_pc;
            if (enable_i and valid_i) = '1' then
                latch_branch <= branch;
            end if;
            if (enable_i and valid_i) = '1' then
                branch_pc <= alu2_y;
                pc <= pc_i;
            end if;
            exception_taken_o <= ecall or ebreak or exception_valid_i;
            exception_exit_o <= mret;
        end if;
    end process;
    epc <= 
        pc when sync_exception = '1' else
        branch_pc when latch_branch = '1' else
        std_logic_vector(unsigned(pc) + 4);

    next_stage_ready <= 
        '0' when writeback_valid = '1' and writeback_ready_i = '0' else
        '0' when memory_valid = '1' and memory_ready_i = '0' else
        '0' when csr_valid = '1' and csr_ready_i = '0' else
        '1';
    ready_o <= enable_i and next_stage_ready;
    exception_pc_o <= epc;
end architecture rtl;