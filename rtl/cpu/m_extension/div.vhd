library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity div is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        num_i : in std_logic_vector(31 downto 0);
        den_i : in std_logic_vector(31 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        start_i : in std_logic;
        res_o : out std_logic_vector(31 downto 0);
        ready_o : out std_logic
    );
end entity div;

architecture rtl of div is
    constant C_VERIF : boolean := FALSE;
    type div_state_t is (st_idle, st_check_den, st_divide, st_norm_res, st_inv_den);
    signal result_sel : std_logic;
    signal current_st, next_st : div_state_t;
    signal next_cnt, cnt : unsigned(5 downto 0);
    signal num_is_neg, den_is_neg, den_is_zero : std_logic;
    signal load_q, load_r, load_d : std_logic;
    signal next_d, d : std_logic_vector(31 downto 0);
    signal next_q, q, next_r, r : std_logic_vector(31 downto 0);
    signal alu_a, alu_b, alu_y : std_logic_vector(32 downto 0);
    signal ready : std_logic;
begin
    
-- FSM
    process (current_st, start_i, den_is_zero, cnt)
    begin
        case current_st is
            when st_idle =>
                if start_i = '1' then
                    next_st <= st_check_den;
                else
                    next_st <= st_idle;
                end if;
            when st_check_den =>
                if den_is_zero = '1' then
                    next_st <= st_inv_den;
                else
                    next_st <= st_divide;
                end if;
            when st_divide =>
                if cnt(cnt'left) = '1' then
                    next_st <= st_norm_res;
                else
                    next_st <= st_divide;
                end if;
            when st_norm_res =>
                next_st <= st_idle;
            when st_inv_den =>
                next_st <= st_idle;
            when others =>
                next_st <= st_idle;
        end case;
    end process;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            current_st <= st_idle;
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                current_st <= st_idle;
            else
                current_st <= next_st;
            end if;
        end if;
    end process;

    process (current_st, num_i, q, r, alu_y, num_is_neg, den_is_neg, start_i)
    begin
        case current_st is
            when st_idle =>
                next_q <= num_i; load_q <= start_i;
                next_r <= (others => '0'); load_r <= start_i;
            when st_check_den =>
                next_q <= std_logic_vector(unsigned(not q) + 1); load_q <= num_is_neg;
                next_r <= (others => '0'); load_r <= '1';
            when st_divide =>
                next_q <= q(30 downto 0) & not alu_y(alu_y'left); load_q <= '1'; load_r <= '1';
                if alu_y(alu_y'left) = '1' then
                    next_r <= r(30 downto 0) & q(q'left);
                else
                    next_r <= alu_y(31 downto 0);
                end if;
            when st_norm_res =>
                next_q <= std_logic_vector(unsigned(not q) + 1); load_q <= (num_is_neg xor den_is_neg);
                next_r <= std_logic_vector(unsigned(not r) + 1); load_r <= num_is_neg;
            when st_inv_den =>
                next_q <= (others => '1'); load_q <= '1'; load_r <= '1';
                if num_is_neg = '1' then
                    next_r <= std_logic_vector(unsigned(not q) + 1);
                else
                    next_r <= q;
                end if;
            when others =>
                next_q <= (others => 'X'); load_q <= '0';
                next_r <= (others => 'X'); load_r <= '0';
        end case;
    end process;

    process (current_st, den_i, d, den_is_neg)
    begin
        case current_st is
            when st_idle => next_d <= den_i; load_d <= '1';
            when st_check_den => next_d <= std_logic_vector(unsigned(not d) + 1); load_d <= den_is_neg;
            when others => next_d <= (others => 'X'); load_d <= '0';
        end case;
    end process;

    process (current_st, cnt)
    begin
        if current_st = st_divide then
            next_cnt <= cnt + 1;
        else
            next_cnt <= to_unsigned(1, next_cnt'length);
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            cnt <= next_cnt;
            if load_q = '1' then
                q <= next_q;
            end if;
            if load_r = '1' then
                r <= next_r;
            end if;
            if load_d = '1' then
                d <= next_d;
            end if;
            if ready = '1' then
                num_is_neg <= num_i(num_i'left) and not funct3_i(0);
                den_is_neg <= den_i(den_i'left) and not funct3_i(0);
                result_sel <= funct3_i(1);
            end if;
        end if;
    end process;

    den_is_zero <= '1' when unsigned(d) = 0 else '0';

-- ALU
    alu_a <= r & q(q'left);
    alu_b <= '0' & d;
    alu_y <= std_logic_vector(unsigned(alu_a) - unsigned(alu_b));

-- Status
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            ready <= '1';
        elsif rising_edge(clk_i) then
            if next_st /= st_idle then
                ready <= '0';
            else
                ready <= '1';
            end if;
        end if;
    end process;
    ready_o <= ready;
    res_o <= 
        q when result_sel = '0' else
        r;

-- Verification
gen_verif: if C_VERIF = TRUE generate
    signal d_current_st : div_state_t;
    signal expected_res : std_logic_vector(31 downto 0);
begin
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            d_current_st <= current_st;
            if start_i = '1' then
                if unsigned(den_i) = 0 then
                    if funct3_i(1) = '0' then
                        expected_res <= (others => '1');
                    else
                        expected_res <= num_i;
                    end if;
                else
                    case funct3_i(1 downto 0) is
                        when "00" => expected_res <= std_logic_vector(signed(num_i) / signed(den_i));
                        when "01" => expected_res <= std_logic_vector(unsigned(num_i) / unsigned(den_i));
                        when "10" => expected_res <= std_logic_vector(signed(num_i) rem signed(den_i));
                        when "11" => expected_res <= std_logic_vector(unsigned(num_i) rem unsigned(den_i));
                        when others =>
                    end case;
                end if;
            end if;
            if current_st = st_idle and d_current_st /= st_idle then
                if result_sel = '0' then
                    assert expected_res = q severity FAILURE;
                else
                    assert expected_res = r severity FAILURE;
                end if;
            end if;
        end if;
    end process;
end generate gen_verif;
end architecture rtl;