library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity shifter is
    generic (
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        shift_i : in std_logic_vector(4 downto 0);
        type_i : in std_logic_vector(1 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        start_i : in std_logic;
        data_o : out std_logic_vector(31 downto 0);
        done_o : out std_logic;
        ready_o : out std_logic
    );
end entity shifter;

architecture rtl of shifter is
    signal load_data : std_logic;
    signal nxt_data, data : std_logic_vector(31 downto 0);
    signal nxt_done, done : std_logic;
begin
    gen_light_shifter: if G_FULL_BARREL_SHIFTER = FALSE generate
        type shift_st_t is (st_idle, st_shift);
        signal current_st, next_st : shift_st_t;
        signal load_cnt : std_logic;
        signal nxt_cnt, cnt : unsigned(4 downto 0);
        signal shift_type : std_logic_vector(1 downto 0);
    begin
        process (current_st, start_i, nxt_cnt)
        begin
            case current_st is
                when st_idle =>
                    if start_i = '1' and nxt_cnt /= 0 then
                        next_st <= st_shift;
                    else
                        next_st <= st_idle;
                    end if;
                when st_shift =>
                    if nxt_cnt = 0 then
                        next_st <= st_idle;
                    else
                        next_st <= st_shift;
                    end if;
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

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if load_cnt = '1' then
                    cnt <= nxt_cnt;
                end if;
                if load_data = '1' then
                    data <= nxt_data;
                end if;
                if current_st = st_idle then
                    shift_type <= type_i;
                end if;
            end if;
        end process;

        process (current_st, data_i, data, shift_type, shift_i, start_i, cnt)
        begin
            case current_st is
                when st_idle =>
                    nxt_data <= data_i;
                    nxt_cnt <= unsigned(shift_i);
                    load_data <= start_i;
                    load_cnt <= start_i;
                when st_shift =>
                    nxt_cnt <= cnt - 1;
                    if shift_type(1) = '1' then
                        nxt_data <= (shift_type(0) and data(31)) & data(31 downto 1);
                    else
                        nxt_data <= data(30 downto 0) & '0';
                    end if;
                    load_data <= '1';
                    load_cnt <= '1';
                when others =>
                    nxt_data <= (others => 'X');
                    nxt_cnt <= (others => 'X');
                    load_data <= '0';
                    load_cnt <= '0';
            end case;
        end process;

        nxt_done <= '1' when (next_st = st_idle and current_st = st_shift) or (current_st = st_idle and nxt_cnt = 0 and start_i = '1') else '0';
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                done <= nxt_done;
            end if;
        end process;

        ready_o <= 
            '0' when G_SHIFTER_EARLY_INJECTION = TRUE and next_st = st_shift else
            '0' when G_SHIFTER_EARLY_INJECTION = FALSE and current_st = st_shift else
            '1';

    end generate gen_light_shifter;

    gen_full_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
        function reverse_bit_order (slv_i : in std_logic_vector) return std_logic_vector is
            variable reversed : std_logic_vector(slv_i'length - 1 downto 0);
        begin
            for i in 0 to slv_i'length - 1 loop
                reversed(i) := slv_i(slv_i'length - 1 - i);
            end loop;
            return reversed;
        end function;
        signal norm : std_logic_vector(31 downto 0);
        signal shift : std_logic_vector(32 downto 0);
    begin
        norm <= reverse_bit_order(data_i) when type_i(1) = '0' else data_i;
        shift <= std_logic_vector(shift_right(signed((type_i(0) and norm(31)) & norm), to_integer(unsigned(shift_i))));

        process (type_i, shift)
        begin
            if type_i(1) = '0' then
                nxt_data <= reverse_bit_order(shift(31 downto 0));
            else
                nxt_data <= shift(31 downto 0);
            end if;
        end process;
        gen_no_early_injection: if G_SHIFTER_EARLY_INJECTION = FALSE generate
            process (clk_i)
            begin
                if rising_edge(clk_i) then
                    data <= nxt_data;
                    done <= nxt_done;
                end if;
            end process;
        end generate gen_no_early_injection;
        nxt_done <= start_i;
        ready_o <= '1';
    end generate gen_full_shifter;

    done_o <= 
        nxt_done when G_SHIFTER_EARLY_INJECTION = TRUE else
        done;

    data_o <= 
        nxt_data when G_SHIFTER_EARLY_INJECTION = TRUE else
        data;

end architecture rtl;