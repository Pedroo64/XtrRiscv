library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package rv32i_pkg is
    
    type opcode_t is record
        lui : std_logic;
        auipc : std_logic;
        jal : std_logic;
        jalr : std_logic;
        branch : std_logic;
        load : std_logic;
        store : std_logic;
        reg_imm : std_logic;
        reg_reg : std_logic;
        fence : std_logic;
        sys : std_logic;
        illegal : std_logic;
    end record opcode_t;

    type opcode_type_t is record
        r_type : std_logic;
        i_type : std_logic;
        s_type : std_logic;
        b_type : std_logic;
        u_type : std_logic;
        j_type : std_logic;
    end record;

    type execute_ctrl_t is record
        alu_op_a_sel : std_logic;
        alu_op_b_sel : std_logic;
        alu_op : std_logic_vector(1 downto 0);
        alu_arith : std_logic;
        alu_res_sel : std_logic_vector(2 downto 0);
        shifter_en : std_logic;
        muldiv_en : std_logic;
    end record;


    -- RV32I Base Instruction Set Opcodes
constant RV32I_OP_LUI       :   std_logic_vector(6 downto 0) := "0110111";
constant RV32I_OP_AUIPC     :   std_logic_vector(6 downto 0) := "0010111";
constant RV32I_OP_JAL       :   std_logic_vector(6 downto 0) := "1101111";
constant RV32I_OP_JALR      :   std_logic_vector(6 downto 0) := "1100111";
constant RV32I_OP_BRANCH    :   std_logic_vector(6 downto 0) := "1100011";
constant RV32I_OP_LOAD      :   std_logic_vector(6 downto 0) := "0000011";
constant RV32I_OP_STORE     :   std_logic_vector(6 downto 0) := "0100011";
constant RV32I_OP_REG_IMM   :   std_logic_vector(6 downto 0) := "0010011";
constant RV32I_OP_REG_REG   :   std_logic_vector(6 downto 0) := "0110011";
constant RV32I_OP_FENCE     :   std_logic_vector(6 downto 0) := "0001111";
constant RV32I_OP_SYS       :   std_logic_vector(6 downto 0) := "1110011";


-- Funct3 codes
constant RV32I_FN3_ADD           :   std_logic_vector(2 downto 0) := "000";
constant RV32I_FN3_SL            :   std_logic_vector(2 downto 0) := "001";
constant RV32I_FN3_SLT           :   std_logic_vector(2 downto 0) := "010";
constant RV32I_FN3_SLTU          :   std_logic_vector(2 downto 0) := "011";
constant RV32I_FN3_XOR           :   std_logic_vector(2 downto 0) := "100";
constant RV32I_FN3_SR            :   std_logic_vector(2 downto 0) := "101";
constant RV32I_FN3_OR            :   std_logic_vector(2 downto 0) := "110";
constant RV32I_FN3_AND           :   std_logic_vector(2 downto 0) := "111";

-- SYS codes
constant RV32I_SYS_ECALL        :   std_logic_vector(11 downto 0) := "000000000000";
constant RV32I_SYS_EBREAK       :   std_logic_vector(11 downto 0) := "000000000001";
constant RV32I_SYS_MRET         :   std_logic_vector(11 downto 0) := "001100000010";
--constant RV32I_SYS_RDCYCLE       :   std_logic_vector := "110000000000";
--constant RV32I_SYS_RDCYCLEH      :   std_logic_vector := "110010000000";
--constant RV32I_SYS_RDTIME        :   std_logic_vector := "110000000001";
--constant RV32I_SYS_RDTIMEH       :   std_logic_vector := "110010000001";
--constant RV32I_SYS_RDINSTRET     :   std_logic_vector := "110000000010";
--constant RV32I_SYS_RDINSTRETH    :   std_logic_vector := "110010000010";
constant RV32I_FN3_TRAP         :   std_logic_vector(2 downto 0) := "000";

-- Csr Operation
constant RV32I_FN3_CSRRW        :   std_logic_vector(2 downto 0) := "001";
constant RV32I_FN3_CSRRS        :   std_logic_vector(2 downto 0) := "010";
constant RV32I_FN3_CSRRC        :   std_logic_vector(2 downto 0) := "011";
constant RV32I_FN3_CSRRWI       :   std_logic_vector(2 downto 0) := "101";
constant RV32I_FN3_CSRRSI       :   std_logic_vector(2 downto 0) := "110";
constant RV32I_FN3_CSRRCI       :   std_logic_vector(2 downto 0) := "111";

-- Specialized registers: zero
constant RV32I_ZERO             :   std_logic_vector(4 downto 0) := "00000";

-- Memory access width
constant RV32I_FN3_LB           :   std_logic_vector(1 downto 0) := "00";
constant RV32I_FN3_LH           :   std_logic_vector(1 downto 0) := "01";
constant RV32I_FN3_LW           :   std_logic_vector(1 downto 0) := "10";

constant RV32I_FN3_SB           :   std_logic_vector(1 downto 0) := "00";
constant RV32I_FN3_SH           :   std_logic_vector(1 downto 0) := "01";
constant RV32I_FN3_SW           :   std_logic_vector(1 downto 0) := "10";

-- Test conditions
constant RV32I_FN3_BEQ          :   std_logic_vector(2 downto 0) := "000";
constant RV32I_FN3_BNE          :   std_logic_vector(2 downto 0) := "001";
constant RV32I_FN3_BLT          :   std_logic_vector(2 downto 0) := "100";
constant RV32I_FN3_BGE          :   std_logic_vector(2 downto 0) := "101";
constant RV32I_FN3_BLTU         :   std_logic_vector(2 downto 0) := "110";
constant RV32I_FN3_BGEU         :   std_logic_vector(2 downto 0) := "111";

-- Mul/Div operations
constant RV32M_FN3_MUL          :   std_logic_vector(2 downto 0) := "000";
constant RV32M_FN3_MULH         :   std_logic_vector(2 downto 0) := "001";
constant RV32M_FN3_MULHSU       :   std_logic_vector(2 downto 0) := "010";
constant RV32M_FN3_MULHU        :   std_logic_vector(2 downto 0) := "011";
constant RV32M_FN3_DIV          :   std_logic_vector(2 downto 0) := "100";
constant RV32M_FN3_DIVU         :   std_logic_vector(2 downto 0) := "101";
constant RV32M_FN3_REM          :   std_logic_vector(2 downto 0) := "110";
constant RV32M_FN3_REMU         :   std_logic_vector(2 downto 0) := "111";

constant RV32M_FN7_MULDIV       :   std_logic_vector(6 downto 0) := "0000001";
constant RV32M_FN7_SA           :   std_logic_vector(6 downto 0) := "0100000";
constant RV32M_FN7_SL           :   std_logic_vector(6 downto 0) := "0000000";
constant RV32M_FN7_SUB          :   std_logic_vector(6 downto 0) := "0100000";

end package rv32i_pkg;