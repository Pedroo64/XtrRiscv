library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity muldiv is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        start_i : in std_logic;
        result_o : out std_logic_vector(31 downto 0);
        ready_o : out std_logic
    );
end entity muldiv;


architecture rtl of muldiv is
    signal result_sel : std_logic;
    signal mul_start, div_start : std_logic;
    signal mul_res, div_res : std_logic_vector(31 downto 0);
    signal mul_ready, div_ready : std_logic;
begin
-- LOGIC
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if start_i = '1' then
                result_sel <= funct3_i(2);
            end if;
        end if;
    end process;
-- MUL
    mul_start <= '1' when start_i = '1' and funct3_i(2) = '0' else '0';
--    mul_res <= (others => '0');
--    mul_ready <= '1';
    u_mul : entity work.mul
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            a_i => a_i,
            b_i => b_i,
            funct3_i => funct3_i,
            start_i => mul_start,
            res_o => mul_res,
            ready_o => mul_ready
        );
-- DIV
    div_start <= '1' when start_i = '1' and funct3_i(2) = '1' else '0';
    u_div : entity work.div
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            num_i => a_i,
            den_i => b_i,
            funct3_i => funct3_i,
            start_i => div_start,
            res_o => div_res,
            ready_o => div_ready
        );
-- RESULT
    process (result_sel, mul_res, div_res)
    begin
        if result_sel = '0' then
            result_o <= mul_res;
        else
            result_o <= div_res;
        end if;
    end process;
    ready_o <= mul_ready and div_ready;

end architecture rtl;