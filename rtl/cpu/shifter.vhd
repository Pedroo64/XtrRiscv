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
        type_i : in std_logic_vector(1 downto 0);
        shmt_i : in std_logic_vector(4 downto 0);
        valid_i : in std_logic;
        data_i : in std_logic_vector(31 downto 0);
        valid_o : out std_logic;
        data_o : out std_logic_vector(31 downto 0);
        ready_o : out std_logic
    );
end entity shifter;

architecture rtl of shifter is
    function reverse_bit_order (slv_i : in std_logic_vector) return std_logic_vector is
        variable reversed : std_logic_vector(slv_i'length - 1 downto 0);
    begin
        for i in 0 to slv_i'length - 1 loop
            reversed(i) := slv_i(slv_i'length - 1 - i);
        end loop;
        return reversed;
    end function;
    signal data : std_logic_vector(31 downto 0);
begin
    gen_light_shifter: if G_FULL_BARREL_SHIFTER = FALSE generate
        signal norm : std_logic_vector(31 downto 0);
        signal op_q : std_logic_vector(1 downto 0);
        signal data_q : std_logic_vector(31 downto 0);
        signal cnt, cnt_q : unsigned(5 downto 0);
    begin

        cnt <= cnt_q - 1;
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                cnt_q <= (others => '0');
            elsif rising_edge(clk_i) then
                if valid_i = '1' then
                    cnt_q <= '0' & unsigned(shmt_i);
                elsif cnt(cnt'left) = '0' then
                    cnt_q <= cnt;
                end if;
            end if;
        end process;

        norm <= reverse_bit_order(data_q) when op_q(1) = '0' else data_q;
        data <= (op_q(0) and norm(31)) & norm(31 downto 1);
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if valid_i = '1' then
                    data_q <= data_i;
                    op_q <= type_i;
                elsif cnt_q(5) = '0' then
                    data_q <= data;
                end if;
            end if;
        end process;

        ready_o <= cnt(cnt'left);
        valid_o <= '0';
        data_o  <= data_q;

    end generate gen_light_shifter;

    gen_full_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
        signal norm : std_logic_vector(31 downto 0);
        signal shift : std_logic_vector(32 downto 0);
    begin

        norm <= reverse_bit_order(data_i) when type_i(1) = '0' else data_i;
        shift <= std_logic_vector(shift_right(signed((type_i(0) and norm(31)) & norm), to_integer(unsigned(shmt_i))));
        data  <= reverse_bit_order(shift(31 downto 0)) when type_i(1) = '0' else shift(31 downto 0);

        ready_o <= '1';
        valid_o <= '0';
        data_o  <= data;

    end generate gen_full_shifter;
    -- gen_full_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
    --     function reverse_bit_order (slv_i : in std_logic_vector) return std_logic_vector is
    --         variable reversed : std_logic_vector(slv_i'length - 1 downto 0);
    --     begin
    --         for i in 0 to slv_i'length - 1 loop
    --             reversed(i) := slv_i(slv_i'length - 1 - i);
    --         end loop;
    --         return reversed;
    --     end function;
    --     signal op_q : std_logic_vector(1 downto 0);
    --     signal shmt_q : std_logic_vector(4 downto 0);
    --     signal norm, data_q, data : std_logic_vector(31 downto 0);
    --     signal shift : std_logic_vector(32 downto 0);
    -- begin

    --     norm <= reverse_bit_order(data_q) when type_i(1) = '0' else data_q;

    --     process (clk_i)
    --     begin
    --         if valid_i = '1' then
    --             data_q <= data_i;
    --             shmt_q <= shmt_i;
    --             op_q   <= type_i;
    --         else
    --             data_q <= (others => '-');
    --             shmt_q <= (others => '-');
    --             op_q   <= (others => '-');
    --         end if;
    --     end process;

    --     shift <= std_logic_vector(shift_right(signed((op_q(0) and norm(31)) & norm), to_integer(unsigned(shmt_q))));
    --     data  <= reverse_bit_order(shift(31 downto 0)) when op_q(1) = '0' else shift(31 downto 0);

    --     ready_o <= '1';
    --     valid_o <= '0';
    --     data_o  <= data;

    -- end generate gen_full_shifter;
    -- gen_full_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
    --     function reverse_bit_order (slv_i : in std_logic_vector) return std_logic_vector is
    --         variable reversed : std_logic_vector(slv_i'length - 1 downto 0);
    --     begin
    --         for i in 0 to slv_i'length - 1 loop
    --             reversed(i) := slv_i(slv_i'length - 1 - i);
    --         end loop;
    --         return reversed;
    --     end function;
    --     signal norm : std_logic_vector(31 downto 0);
    --     signal shift : std_logic_vector(32 downto 0);
    -- begin
    --     norm <= reverse_bit_order(data_i) when type_i(1) = '0' else data_i;
    --     shift <= std_logic_vector(shift_right(signed((type_i(0) and norm(31)) & norm), to_integer(unsigned(shift_i))));

    --     process (type_i, shift)
    --     begin
    --         if type_i(1) = '0' then
    --             nxt_data <= reverse_bit_order(shift(31 downto 0));
    --         else
    --             nxt_data <= shift(31 downto 0);
    --         end if;
    --     end process;
    --     gen_no_early_injection: if G_SHIFTER_EARLY_INJECTION = FALSE generate
    --         process (clk_i)
    --         begin
    --             if rising_edge(clk_i) then
    --                 data <= nxt_data;
    --                 done <= nxt_done;
    --             end if;
    --         end process;
    --     end generate gen_no_early_injection;
    --     nxt_done <= start_i;
    --     ready_o <= '1';
    -- end generate gen_full_shifter;

    -- done_o <=
    --     nxt_done when G_SHIFTER_EARLY_INJECTION = TRUE else
    --     done;

    -- data_o <=
    --     nxt_data when G_SHIFTER_EARLY_INJECTION = TRUE else
    --     data;

end architecture rtl;