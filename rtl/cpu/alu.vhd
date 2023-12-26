library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu is
    port (
        arith_a_i : in std_logic_vector(31 downto 0);
        arith_b_i : in std_logic_vector(31 downto 0);
        signed_i : in std_logic;
        arith_op_i : in std_logic;
        logic_a_i : in std_logic_vector(31 downto 0);
        logic_b_i : in std_logic_vector(31 downto 0);
        logic_op_i : in std_logic_vector(1 downto 0);
        arith_result_o : out std_logic_vector(32 downto 0);
        logic_result_o : out std_logic_vector(31 downto 0)
    );
end entity alu;

architecture rtl of alu is
    signal ea, eb, eres : unsigned(32 downto 0);
begin
    
    ea <= (arith_a_i(arith_a_i'left) and signed_i) & unsigned(arith_a_i);
    eb <= (arith_b_i(arith_b_i'left) and signed_i) & unsigned(arith_b_i);

    eres <= ea - eb when arith_op_i = '1' else ea + eb;
    arith_result_o <= std_logic_vector(eres);

    with logic_op_i select
        logic_result_o <= 
            logic_a_i and logic_b_i when "11",
            logic_a_i or logic_b_i when "10",
            logic_a_i xor logic_b_i when "00",
            (others => '-') when others;

end architecture rtl;