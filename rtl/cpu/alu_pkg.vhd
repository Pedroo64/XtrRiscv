library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package alu_pkg is
    
    constant ALU_OP_ADD : std_logic_vector(2 downto 0) := "000";
    constant ALU_OP_SUB : std_logic_vector(2 downto 0) := "001";
    constant ALU_OP_AND : std_logic_vector(2 downto 0) := "010";
    constant ALU_OP_OR : std_logic_vector(2 downto 0)  := "011";
    constant ALU_OP_XOR : std_logic_vector(2 downto 0) := "100";
    constant ALU_OP_SLL : std_logic_vector(2 downto 0) := "101";
    constant ALU_OP_SRL : std_logic_vector(2 downto 0) := "110";
    constant ALU_OP_SRA : std_logic_vector(2 downto 0) := "111";
    constant ALU_OP_COMPARE : std_logic_vector(2 downto 0) := ALU_OP_SUB;

end package alu_pkg;