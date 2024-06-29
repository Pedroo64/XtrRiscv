library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity div is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        enable_i : in std_logic;
        flush_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        num_i : in std_logic_vector(31 downto 0);
        den_i : in std_logic_vector(31 downto 0);
        quo_o : out std_logic_vector(31 downto 0);
        rem_o : out std_logic_vector(31 downto 0);
        ready_o : out std_logic
    );
end entity div;

architecture rtl of div is
    type div_state_t is (st_idle, st_check_den, st_divide, st_norm_res, st_inv_den);
    signal current_st, next_st : div_state_t;
    signal funct3_q : std_logic_vector(2 downto 0);
    signal cnt, cnt_q : unsigned(5 downto 0);
    signal num_is_neg_q, den_is_neg_q, den_is_zero : std_logic;
    signal load_quo, load_rem, load_den : std_logic;
    signal nxt_den, den_q : std_logic_vector(31 downto 0);
    signal nxt_quo, quo_q, nxt_rem, rem_q : std_logic_vector(31 downto 0);
    signal alu_a, alu_b, alu_y : std_logic_vector(32 downto 0);
    signal ready_q : std_logic;
begin

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                funct3_q <= funct3_i;
            end if;
        end if;
    end process;
    
-- FSM
    process (current_st, enable_i, den_is_zero, cnt_q)
    begin
        case current_st is
            when st_idle =>
                if enable_i = '1' then
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
                if cnt_q(cnt_q'left) = '1' then
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
            if flush_i = '1' then
                current_st <= st_idle;
            else
                current_st <= next_st;
            end if;
        end if;
    end process;

    process (current_st, num_i, quo_q, rem_q, alu_y, num_is_neg_q, den_is_neg_q, enable_i)
    begin
        case current_st is
            when st_idle =>
                nxt_quo <= num_i; load_quo <= enable_i;
                nxt_rem <= (others => '0'); load_rem <= enable_i;
            when st_check_den =>
                nxt_quo <= std_logic_vector(unsigned(not quo_q) + 1); load_quo <= num_is_neg_q;
                nxt_rem <= (others => '0'); load_rem <= '1';
            when st_divide =>
                nxt_quo <= quo_q(30 downto 0) & not alu_y(alu_y'left); load_quo <= '1'; load_rem <= '1';
                if alu_y(alu_y'left) = '1' then
                    nxt_rem <= rem_q(30 downto 0) & quo_q(quo_q'left);
                else
                    nxt_rem <= alu_y(31 downto 0);
                end if;
            when st_norm_res =>
                nxt_quo <= std_logic_vector(unsigned(not quo_q) + 1); load_quo <= (num_is_neg_q xor den_is_neg_q);
                nxt_rem <= std_logic_vector(unsigned(not rem_q) + 1); load_rem <= num_is_neg_q;
            when st_inv_den =>
                nxt_quo <= (others => '1'); load_quo <= '1'; load_rem <= '1';
                if num_is_neg_q = '1' then
                    nxt_rem <= std_logic_vector(unsigned(not quo_q) + 1);
                else
                    nxt_rem <= quo_q;
                end if;
            when others =>
                nxt_quo <= (others => 'X'); load_quo <= '0';
                nxt_rem <= (others => 'X'); load_rem <= '0';
        end case;
    end process;

    process (current_st, den_i, den_q, den_is_neg_q)
    begin
        case current_st is
            when st_idle => nxt_den <= den_i; load_den <= '1';
            when st_check_den => nxt_den <= std_logic_vector(unsigned(not den_q) + 1); load_den <= den_is_neg_q;
            when others => nxt_den <= (others => 'X'); load_den <= '0';
        end case;
    end process;

    cnt <= cnt_q + 1;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if current_st = st_divide then
                cnt_q <= cnt;
            else
                cnt_q <= to_unsigned(1, cnt'length);
            end if;
            if load_quo = '1' then
                quo_q <= nxt_quo;
            end if;
            if load_rem = '1' then
                rem_q <= nxt_rem;
            end if;
            if load_den = '1' then
                den_q <= nxt_den;
            end if;
            if ready_q = '1' then
                num_is_neg_q <= num_i(num_i'left) and not funct3_q(0);
                den_is_neg_q <= den_i(den_i'left) and not funct3_q(0);
            end if;
        end if;
    end process;

    den_is_zero <= '1' when unsigned(den_q) = 0 else '0';

-- ALU
    alu_a <= rem_q & quo_q(quo_q'left);
    alu_b <= '0' & den_q;
    alu_y <= std_logic_vector(unsigned(alu_a) - unsigned(alu_b));

-- Status
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            ready_q <= '1';
        elsif rising_edge(clk_i) then
            if next_st /= st_idle then
                ready_q <= '0';
            else
                ready_q <= '1';
            end if;
        end if;
    end process;
    ready_o <= ready_q;
    quo_o <= quo_q;
    rem_o <= rem_q;

end architecture rtl;