library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity comparator is
    port (
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        signed_i : in std_logic;
        lt_o : out std_logic;
        eq_o : out std_logic
    );
end entity comparator;

architecture rtl of comparator is
    signal ea, eb : signed(32 downto 0);
begin
    
    ea <= signed((signed_i and a_i(a_i'left)) & a_i);
    eb <= signed((signed_i and b_i(b_i'left)) & b_i);

    lt_o <= '1' when ea < eb else '0';
    eq_o <= '1' when ea = eb else '0';
    
end architecture rtl;