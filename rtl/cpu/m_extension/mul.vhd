library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mul is
    generic (
        G_FAST_MUL : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        enable_i : in std_logic;
        flush_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_dat_i : in std_logic_vector(31 downto 0);
        result_o : out std_logic_vector(63 downto 0);
        ready_o : out std_logic
    );
end entity mul;

architecture rtl of mul is
    signal ready_q : std_logic;
    signal signed_a, signed_b : std_logic;
begin

    signed_a <= not (funct3_i(1) and funct3_i(0));
    signed_b <= not funct3_i(1);

    gen_iter: if G_FAST_MUL = FALSE generate
        signal cnt, cnt_q : unsigned(5 downto 0);
        signal alu_a, alu_b, alu_y : std_logic_vector(32 downto 0);
        signal alu_op_q : std_logic;
        signal load_product, load_multiplicand : std_logic;
        signal multiplicand, multiplicand_q : std_logic_vector(31 downto 0);
        signal product, product_q : std_logic_vector(63 downto 0);
        signal signed_a_q, signed_b_q : std_logic;
    begin
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if ready_q = '1' and enable_i = '1' then
                    signed_a_q <= signed_a;
                    signed_b_q <= signed_b;
                end if;
            end if;
        end process;

        alu_a <= (signed_a_q and product_q(63)) & product_q(63 downto 32);
        alu_b <= (signed_a_q and multiplicand_q(31)) & multiplicand_q;

        alu_y <=
            std_logic_vector(unsigned(alu_a) - unsigned(alu_b)) when alu_op_q = '1' else
            std_logic_vector(unsigned(alu_a) + unsigned(alu_b));

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                ready_q <= '1';
            elsif rising_edge(clk_i) then
                if enable_i = '1' or cnt_q(cnt_q'left) = '1' or flush_i = '1' then
                    ready_q <= flush_i or cnt_q(cnt_q'left);
                end if;
            end if;
        end process;

        process (ready_q, rs2_dat_i, alu_y, signed_a_q, product_q, enable_i)
        begin
            if ready_q = '1' then
                product(63 downto 32) <= (others => '0');
                product(31 downto 0) <= rs2_dat_i;
                load_product <= enable_i;
            else
                if product_q(0) = '1' then
                    product(63 downto 31) <= alu_y;
                else
                    product(63 downto 31) <= (signed_a_q and product_q(63)) & product_q(63 downto 32);
                end if;
                product(30 downto 0) <= product_q(31 downto 1);
                load_product <= '1';
            end if;
        end process;

        process (rs1_dat_i, ready_q)
        begin
            multiplicand <= rs1_dat_i;
            load_multiplicand <= ready_q;
        end process;

        cnt <= cnt_q + 1;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if load_multiplicand = '1' then
                    multiplicand_q <= multiplicand;
                end if;
                if load_product = '1' then
                    product_q <= product;
                end if;
                if ready_q = '1' then
                    cnt_q <= to_unsigned(1, cnt_q'length);
                else
                    cnt_q <= cnt;
                end if;
                alu_op_q <= cnt(cnt'left) and signed_b_q;
            end if;
        end process;
        result_o <= product_q;
    end generate gen_iter;

    gen_dsp: if G_FAST_MUL = TRUE generate
        signal ex_q, mem_q : std_logic;
        signal rs1_dat_q, rs2_dat_q : signed(32 downto 0);
        signal product : signed(65 downto 0);
        signal product_q, d_product_q : std_logic_vector(63 downto 0);
    begin
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                ready_q <= '1';
            elsif rising_edge(clk_i) then
                if enable_i = '1' or flush_i = '1' or mem_q = '1' then
                    ready_q <= flush_i or mem_q;
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if enable_i = '1' or flush_i = '1' or ex_q = '1' then
                    ex_q <= not (flush_i or ex_q);
                end if;
                if ex_q = '1' or mem_q = '1' or flush_i = '1' then
                    mem_q <= ex_q and not (flush_i or mem_q);
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if ready_q = '1' and enable_i = '1' then
                    rs1_dat_q <= (signed_a and rs1_dat_i(rs1_dat_i'left)) & signed(rs1_dat_i);
                    rs2_dat_q <= (signed_b and rs2_dat_i(rs2_dat_i'left)) & signed(rs2_dat_i);
                end if;
            end if;
        end process;

        product <= rs1_dat_q * rs2_dat_q;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                product_q <= std_logic_vector(product(63 downto 0));
                d_product_q <= product_q;
            end if;
        end process;

        result_o <= d_product_q;

    end generate gen_dsp;

    ready_o <= ready_q;

end architecture rtl;
