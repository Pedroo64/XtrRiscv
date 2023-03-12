library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity alu is
    port (
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        signed_i : in std_logic;
        arith_op_i : in std_logic;
        logic_op_i : in std_logic_vector(1 downto 0);
        arith_result_o : out std_logic_vector(32 downto 0);
        logic_result_o : out std_logic_vector(31 downto 0)
    );
end entity alu;

architecture rtl of alu is
    signal ea, eb, eres : unsigned(32 downto 0);
begin
    
    ea <= (a_i(a_i'left) and signed_i) & unsigned(a_i);
    eb <= (b_i(b_i'left) and signed_i) & unsigned(b_i);

    eres <= ea - eb when arith_op_i = '1' else ea + eb;
    arith_result_o <= std_logic_vector(eres);

    with logic_op_i select
        logic_result_o <= 
            a_i and b_i when "11",
            a_i or b_i when "10",
            a_i xor b_i when others;

end architecture rtl;