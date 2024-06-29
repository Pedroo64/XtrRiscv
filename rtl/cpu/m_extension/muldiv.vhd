library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity muldiv is
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
        result_o : out std_logic_vector(31 downto 0);
        ready_o : out std_logic
    );
end entity muldiv;


architecture rtl of muldiv is
    signal funct3_q : std_logic_vector(2 downto 0);
    signal mul_enable, div_enable, mul_ready, div_ready : std_logic;
    signal mul_res : std_logic_vector(63 downto 0);
    signal div_quo, div_rem : std_logic_vector(31 downto 0);
begin
-- LOGIC
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                funct3_q <= funct3_i;
            end if;
        end if;
    end process;
-- MUL
    mul_enable <= '1' when enable_i = '1' and funct3_i(2) = '0' else '0';
--    mul_res <= (others => '0');
--    mul_ready <= '1';
    u_mul : entity work.mul
        generic map (
            G_FAST_MUL => G_FAST_MUL
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            enable_i => mul_enable,
            flush_i => flush_i,
            funct3_i => funct3_i,
            rs1_dat_i => rs1_dat_i,
            rs2_dat_i => rs2_dat_i,
            result_o => mul_res,
            ready_o => mul_ready
        );
-- DIV
    div_enable <= '1' when enable_i = '1' and funct3_i(2) = '1' else '0';
    u_div : entity work.div
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            enable_i => div_enable,
            flush_i => flush_i,
            funct3_i => funct3_i,
            num_i => rs1_dat_i,
            den_i => rs2_dat_i,
            quo_o => div_quo,
            rem_o => div_rem,
            ready_o => div_ready
        );
-- RESULT
    process (funct3_q, mul_res, div_quo, div_rem)
    begin
        case funct3_q(2 downto 0) is
            when "000" => result_o <= mul_res(31 downto 0);
            when "001" => result_o <= mul_res(63 downto 32);
            when "010" => result_o <= mul_res(63 downto 32);
            when "011" => result_o <= mul_res(63 downto 32);
            when "100" => result_o <= div_quo(31 downto 0);
            when "101" => result_o <= div_quo(31 downto 0);
            when "110" => result_o <= div_rem(31 downto 0);
            when "111" => result_o <= div_rem(31 downto 0);
            when others =>
        end case;
    end process;
    ready_o <= mul_ready and div_ready;

end architecture rtl;