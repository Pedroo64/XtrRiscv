library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package alu_pkg is
    
    type alu_op_t is (ALU_OP_ADD, ALU_OP_SUB, ALU_OP_AND, ALU_OP_OR, ALU_OP_XOR, ALU_OP_SLL, ALU_OP_SRL, ALU_OP_SRA, ALU_OP_SLT, ALU_OP_SLTU, ALU_OP_NOP);

end package alu_pkg;