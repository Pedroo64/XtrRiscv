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
        opcode_i : in std_logic_vector(6 downto 0);
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
        memory_valid_o : out std_logic;
        memory_address_o : out std_logic_vector(31 downto 0);
        memory_data_o : out std_logic_vector(31 downto 0);
        memory_we_o : out std_logic;
        memory_size_o : out std_logic_vector(2 downto 0);
        memory_ready_i : in std_logic;
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
        pc_i when opcode_i = RV32I_OP_AUIPC else
        pc_i when opcode_i = RV32I_OP_JAL else
        pc_i when opcode_i = RV32I_OP_JALR else
        rs1_dat_i when opcode_i = RV32I_OP_REG_IMM else
        rs1_dat_i when opcode_i = RV32I_OP_REG_REG else
        rs1_dat_i when opcode_i = RV32I_OP_LOAD else
        rs1_dat_i when opcode_i = RV32I_OP_STORE else
        rs1_dat_i when opcode_i = RV32I_OP_BRANCH else
        rs1_dat_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRW else
        rs1_dat_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRS else
        rs1_dat_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRC else
        (5 to 31 => '0') & rs1_adr_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRWI else
        (5 to 31 => '0') & rs1_adr_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRSI else
        (5 to 31 => '0') & rs1_adr_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRCI else
        (others => '0');

    alu1_b <= 
        immediate_i when opcode_i = RV32I_OP_LUI else
        immediate_i when opcode_i = RV32I_OP_AUIPC else
        immediate_i when opcode_i = RV32I_OP_REG_IMM else
        immediate_i when opcode_i = RV32I_OP_LOAD else
        immediate_i when opcode_i = RV32I_OP_STORE else
        rs2_dat_i when opcode_i = RV32I_OP_REG_REG else
        rs2_dat_i when opcode_i = RV32I_OP_BRANCH else
        (others => '0') when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRW else
        (others => '0') when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRS else
        (others => '0') when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRC else
        (others => '0') when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRWI else
        (others => '0') when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRSI else
        (others => '1') when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_CSRRCI else
        std_logic_vector(to_unsigned(4, alu1_b'length));

    process (opcode_i, funct3_i, funct7_i(5))
    begin
        case opcode_i is
            when RV32I_OP_LUI | RV32I_OP_AUIPC | RV32I_OP_JAL | RV32I_OP_JALR | RV32I_OP_LOAD | RV32I_OP_STORE =>
                alu1_op <= ALU_OP_ADD;
            when RV32I_OP_REG_IMM | RV32I_OP_REG_REG =>
                case funct3_i is
                    when RV32I_FN3_ADD =>
                        if funct7_i(5) = '1' and opcode_i = RV32I_OP_REG_REG then
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
            when RV32I_OP_BRANCH =>
                alu1_op <= ALU_OP_NOP;
            when RV32I_OP_SYS =>
                alu1_op <= ALU_OP_XOR;
            when others =>
                alu1_op <= ALU_OP_NOP;
        end case;
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
        rs1_dat_i when opcode_i = RV32I_OP_JALR else
        pc_i;

    alu2_b <= immediate_i;

    alu2_op <= ALU_OP_ADD;

    next_pc <= 
        exception_pc_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "10" else
        trap_vector_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_TRAP and immediate_i(1) = '0' else
        trap_vector_i when exception_valid_i = '1' else
        alu2_y;
    
    load_pc <= branch or ecall or ebreak or mret;

    process (opcode_i, funct3_i, alu1_eq, alu1_lt, alu1_ge, alu1_ltu, alu1_geu)
    begin
        case opcode_i is
            when RV32I_OP_JAL | RV32I_OP_JALR =>
                branch <= '1';
            when RV32I_OP_BRANCH =>
                case funct3_i is
                    when RV32I_FN3_BEQ =>
                        branch <= alu1_eq;
                    when RV32I_FN3_BNE =>
                        branch <= not alu1_eq;
                    when RV32I_FN3_BLT =>
                        branch <= alu1_lt;
                    when RV32I_FN3_BGE =>
                        branch <= alu1_ge;
                    when RV32I_FN3_BLTU =>
                        branch <= alu1_ltu;
                    when RV32I_FN3_BGEU =>
                        branch <= alu1_geu;
                    when others =>
                        branch <= '0';
                end case;
            when others =>
                branch <= '0';
        end case;
    end process;

    ecall <= enable_i and valid_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "00" else '0';
    ebreak <= enable_i and valid_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "01" else '0';
    mret <= enable_i and valid_i when opcode_i = RV32I_OP_SYS and funct3_i = RV32I_FN3_TRAP and immediate_i(1 downto 0) = "10" else '0';
    
    writeback_valid <= 
        valid_i and enable_i when opcode_i = RV32I_OP_LUI else 
        valid_i and enable_i when opcode_i = RV32I_OP_AUIPC else 
        valid_i and enable_i when opcode_i = RV32I_OP_JAL else
        valid_i and enable_i when opcode_i = RV32I_OP_JALR else
        valid_i and enable_i when opcode_i = RV32I_OP_REG_IMM else
        valid_i and enable_i when opcode_i = RV32I_OP_REG_REG else
        '0';

    memory_valid <= 
        valid_i and enable_i when opcode_i = RV32I_OP_LOAD else
        valid_i and enable_i when opcode_i = RV32I_OP_STORE else
        '0';

    csr_valid <= 
        valid_i and enable_i when opcode_i = RV32I_OP_SYS and unsigned(funct3_i) /= 0 else
        '0';

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            latch_writeback_valid <= '0';
            latch_memory_valid <= '0';
            latch_csr_valid <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                latch_writeback_valid <= '0';
                latch_memory_valid <= '0';
                latch_csr_valid <= '0';
            else
                if next_stage_ready = '1' then
                    latch_writeback_valid <= writeback_valid;
                    latch_memory_valid <= memory_valid;
                    latch_csr_valid <= csr_valid;
                end if;
            end if;
        end if;
    end process;
    writeback_valid_o <= latch_writeback_valid;
    memory_valid_o <= latch_memory_valid;
    csr_valid_o <= latch_csr_valid;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if (enable_i and valid_i and next_stage_ready) = '1' then
                funct7_o <= funct7_i;
                funct3_o <= funct3_i;
                rd_adr_o <= rd_adr_i;
                rd_dat_o <= rd_dat;
                rd_we_o <= rd_we_i;
                ecall_o <= ecall;
                ebreak_o <= ebreak;
                mret_o <= mret;
                sync_exception <= ecall or ebreak;
                csr_address_o <= immediate_i(11 downto 0);
                csr_data_o <= rd_dat;
                memory_address_o <= alu1_y;
                memory_data_o <= rs2_dat_i;
                memory_size_o <= funct3_i(2 downto 0);
                if opcode_i = RV32I_OP_STORE then
                    memory_we_o <= '1';
                else
                    memory_we_o <= '0';
                end if;
            else
                sync_exception <= '0';
                ecall_o <= '0';
                ebreak_o <= '0';
                mret_o <= '0';
            end if;
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
        '0' when latch_writeback_valid = '1' and writeback_ready_i = '0' else
        '0' when latch_memory_valid = '1' and memory_ready_i = '0' else
        '0' when latch_csr_valid = '1' and csr_ready_i = '0' else
        '1';
    ready_o <= enable_i and next_stage_ready;
    exception_pc_o <= epc;
end architecture rtl;