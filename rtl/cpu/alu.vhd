library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.alu_pkg.all;

entity alu is
    port (
        op_i : in std_logic_vector(2 downto 0);
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        y_o : out std_logic_vector(31 downto 0);
        ge_o : out std_logic;
        eq_o : out std_logic;
        lt_o : out std_logic;
        geu_o : out std_logic;
        ltu_o : out std_logic
    );
end entity alu;

architecture rtl of alu is
    signal a, b, y : unsigned(31 downto 0);
begin
    a <= unsigned(a_i);
    b <= unsigned(b_i);
    process (a, b, op_i)
    begin
        case op_i is
            when ALU_OP_ADD =>
                y <= a + b;
            when ALU_OP_SUB =>
                y <= a - b;
            when ALU_OP_AND =>
                y <= a and b;
            when ALU_OP_OR =>
                y <= a or b;
            when ALU_OP_XOR =>
                y <= a xor b;
            when ALU_OP_SLL =>
                y <= shift_left(a(31 downto 0), to_integer(b(4 downto 0)));
            when ALU_OP_SRL =>
                y <= shift_right(a(31 downto 0), to_integer(b(4 downto 0)));
            when ALU_OP_SRA =>
                y <= unsigned(shift_right(signed(a(31 downto 0)), to_integer(b(4 downto 0))));
            when others =>
                y <= (others => '-');
        end case;
    end process;
    y_o <= std_logic_vector(y(31 downto 0));
    ge_o <= '1' when signed(a) >= signed(b) else '0'; 
    lt_o <= '1' when signed(a) < signed(b) else '0'; 
    geu_o <= '1' when a >= b else '0';
    ltu_o <= '1' when a < b else '0';
    eq_o <= '1' when y(31 downto 0) = 0 else '0';

end architecture rtl;