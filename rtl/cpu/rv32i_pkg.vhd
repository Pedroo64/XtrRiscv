library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package rv32i_pkg is
    
    -- RV32I Base Instruction Set Opcodes
constant RV32I_OP_LUI       :   std_logic_vector := "0110111";
constant RV32I_OP_AUIPC     :   std_logic_vector := "0010111";
constant RV32I_OP_JAL       :   std_logic_vector := "1101111";
constant RV32I_OP_JALR      :   std_logic_vector := "1100111";
constant RV32I_OP_BRANCH    :   std_logic_vector := "1100011";
constant RV32I_OP_LOAD      :   std_logic_vector := "0000011";
constant RV32I_OP_STORE     :   std_logic_vector := "0100011";
constant RV32I_OP_REG_IMM   :   std_logic_vector := "0010011";
constant RV32I_OP_REG_REG   :   std_logic_vector := "0110011";
constant RV32I_OP_FENCE     :   std_logic_vector := "0001111";
constant RV32I_OP_SYS       :   std_logic_vector := "1110011";


-- Funct3 codes
constant RV32I_FN3_ADD           :   std_logic_vector := "000";
constant RV32I_FN3_SL            :   std_logic_vector := "001";
constant RV32I_FN3_SLT           :   std_logic_vector := "010";
constant RV32I_FN3_SLTU          :   std_logic_vector := "011";
constant RV32I_FN3_XOR           :   std_logic_vector := "100";
constant RV32I_FN3_SR            :   std_logic_vector := "101";
constant RV32I_FN3_OR            :   std_logic_vector := "110";
constant RV32I_FN3_AND           :   std_logic_vector := "111";

-- SYS codes
constant RV32I_SYS_ECALL        :   std_logic_vector := "000000000000";
constant RV32I_SYS_EBREAK       :   std_logic_vector := "000000000001";
constant RV32I_SYS_MRET         :   std_logic_vector := "001100000010";
constant RV32I_SYS_DRET         :   std_logic_vector := "011110110010";
--constant RV32I_SYS_RDCYCLE       :   std_logic_vector := "110000000000";
--constant RV32I_SYS_RDCYCLEH      :   std_logic_vector := "110010000000";
--constant RV32I_SYS_RDTIME        :   std_logic_vector := "110000000001";
--constant RV32I_SYS_RDTIMEH       :   std_logic_vector := "110010000001";
--constant RV32I_SYS_RDINSTRET     :   std_logic_vector := "110000000010";
--constant RV32I_SYS_RDINSTRETH    :   std_logic_vector := "110010000010";
constant RV32I_FN3_TRAP         :   std_logic_vector := "000";

-- Csr Operation
constant RV32I_FN3_CSRRW        :   std_logic_vector(2 downto 0) := "001";
constant RV32I_FN3_CSRRS        :   std_logic_vector(2 downto 0) := "010";
constant RV32I_FN3_CSRRC        :   std_logic_vector(2 downto 0) := "011";
constant RV32I_FN3_CSRRWI       :   std_logic_vector(2 downto 0) := "101";
constant RV32I_FN3_CSRRSI       :   std_logic_vector(2 downto 0) := "110";
constant RV32I_FN3_CSRRCI       :   std_logic_vector(2 downto 0) := "111";

-- Specialized registers: zero
constant RV32I_ZERO             :   std_logic_vector := "00000";

-- Memory access width
constant RV32I_LB               :   std_logic_vector := "00";
constant RV32I_LH               :   std_logic_vector := "01";
constant RV32I_LW               :   std_logic_vector := "10";

constant RV32I_SB               :   std_logic_vector := "00";
constant RV32I_SH               :   std_logic_vector := "01";
constant RV32I_SW               :   std_logic_vector := "10";

-- Test conditions
constant RV32I_FN3_BEQ          :   std_logic_vector := "000";
constant RV32I_FN3_BNE          :   std_logic_vector := "001";
constant RV32I_FN3_BLT          :   std_logic_vector := "100";
constant RV32I_FN3_BGE          :   std_logic_vector := "101";
constant RV32I_FN3_BLTU         :   std_logic_vector := "110";
constant RV32I_FN3_BGEU         :   std_logic_vector := "111";


    
end package rv32i_pkg;