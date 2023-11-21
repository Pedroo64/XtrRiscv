library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mul is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        start_i : in std_logic;
        res_o : out std_logic_vector(31 downto 0);
        ready_o : out std_logic
    );
end entity mul;

architecture rtl of mul is
    signal next_cnt, cnt : unsigned(5 downto 0);
    signal alu_a, alu_b, alu_y : std_logic_vector(32 downto 0);
    signal alu_op : std_logic;
    signal funct3 : std_logic_vector(1 downto 0);
    signal signed_a, signed_b : std_logic;
    signal ready : std_logic;
    signal next_multiplicand, multiplicand : std_logic_vector(31 downto 0);
    signal next_product, product : std_logic_vector(63 downto 0);
    signal load_product, load_multiplicand : std_logic;
begin
    
    alu_a <= (signed_a and product(63)) & product(63 downto 32);
    alu_b <= (signed_a and multiplicand(31)) & multiplicand;

    alu_y <= 
        std_logic_vector(unsigned(alu_a) - unsigned(alu_b)) when alu_op = '1' else
        std_logic_vector(unsigned(alu_a) + unsigned(alu_b));

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            ready <= '1';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                ready <= '1';
            else
                if start_i = '1' then
                    ready <= '0';
                elsif cnt(cnt'left) = '1' then
                    ready <= '1';
                end if;
            end if;
        end if;
    end process;

    signed_a <= not (funct3(1) and funct3(0));
    signed_b <= not funct3(1);

    process (ready, b_i, alu_y, signed_a, product, start_i)
    begin
        if ready = '1' then
            next_product(63 downto 32) <= (others => '0');
            next_product(31 downto 0) <= b_i;
            load_product <= start_i;
        else
            if product(0) = '1' then
                next_product(63 downto 31) <= alu_y;
            else
                next_product(63 downto 31) <= (signed_a and product(63)) & product(63 downto 32);
            end if;
            next_product(30 downto 0) <= product(31 downto 1);
            load_product <= '1';
        end if;
    end process;

    process (a_i, ready)
    begin
        next_multiplicand <= a_i;
        load_multiplicand <= ready;
    end process;

    process (ready, cnt)
    begin
        if ready = '1' then
            next_cnt <= to_unsigned(1, next_cnt'length);
        else
            next_cnt <= cnt + 1;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if load_multiplicand = '1' then
                multiplicand <= next_multiplicand;
            end if;
            if load_product = '1' then
                product <= next_product;
            end if;
            if ready = '1' and start_i = '1' then
                funct3 <= funct3_i(1 downto 0);
            end if;
            cnt <= next_cnt;
            alu_op <= next_cnt(cnt'left) and signed_b;
        end if;
    end process;

    res_o <= 
        product(31 downto 0) when funct3(1 downto 0) = "00" else
        product(63 downto 32);

    ready_o <= ready;

end architecture rtl;