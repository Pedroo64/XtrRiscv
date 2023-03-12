library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity shifter is
    generic (
        G_FULL_BARREL_SHIFTER : boolean := FALSE
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
        ready_o : out std_logic;
        ready_i : in std_logic
    );
end entity shifter;

architecture rtl of shifter is
    signal ready : std_logic;
begin
    gen_light_shifter: if G_FULL_BARREL_SHIFTER = FALSE generate
        type shifter_st_t is (st_idle, st_shift, st_hold);
        signal current_st : shifter_st_t;
        signal shift : unsigned(4 downto 0);
        signal data : std_logic_vector(31 downto 0);
        signal shift_type : std_logic_vector(1 downto 0);
    begin
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                current_st <= st_idle;
            elsif rising_edge(clk_i) then
                if srst_i = '1' then
                    current_st <= st_idle;
                else
                    case current_st is
                        when st_idle =>
                            if start_i = '1' then
                                current_st <= st_shift;
                            end if;
                        when st_shift =>
                            if shift = 0 then
                                if ready_i = '0' then
                                    current_st <= st_hold;
                                else
                                    current_st <= st_idle;
                                end if;
                            end if;
                        when st_hold =>
                            if ready_i = '1' then
                                current_st <= st_idle;
                            end if;
                        when others =>
                    end case;
                end if;
            end if;
        end process;
    
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if current_st = st_idle then
                    data <= data_i;
                    shift <= unsigned(shift_i);
                    shift_type <= type_i;
                elsif current_st = st_shift then
                    shift <= shift - 1;
                    if shift > 0 then
                        if shift_type(1) = '0' then 
                            data <= data(data'left - 1 downto 0) & (data(0) and shift_type(0));
                        else
                            data <= (data(data'left) and shift_type(0)) & data(data'left downto 1);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                done_o <= '0';
            elsif rising_edge(clk_i) then
                if srst_i = '1' then
                    done_o <= '0';
                else
                    if (current_st = st_shift and shift = 0) then
                        done_o <= '1';
                    elsif current_st = st_idle then
                        done_o <= '0';
                    end if;
                end if;
            end if;
        end process;
    
        ready <= '0' when current_st /= st_idle else '1';
    
        data_o <= data;
        ready_o <= ready;
    end generate gen_light_shifter;
    gen_full_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
        signal done : std_logic;
    begin
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                done <= '0';
            elsif rising_edge(clk_i) then
                if srst_i = '1' then
                    done <= '0';
                else
                    if start_i = '1' and ready = '1' then
                        done <= '1';
                    elsif ready = '1' then
                        done <= '0';
                    end if;
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if start_i = '1' and ready = '1' then
                    --if type_i(1) = '0' then
                    --    data_o <= left_in5;
                    --else
                    --    data_o <= right_in5;
                    --end if;
                    case to_integer(unsigned(type_i)) is
                        when 16#0# => data_o <= std_logic_vector(shift_left(unsigned(data_i), to_integer(unsigned(shift_i))));
                        when 16#1# => data_o <= std_logic_vector(shift_left(signed(data_i), to_integer(unsigned(shift_i))));
                        when 16#2# => data_o <= std_logic_vector(shift_right(unsigned(data_i), to_integer(unsigned(shift_i))));
                        when 16#3# => data_o <= std_logic_vector(shift_right(signed(data_i), to_integer(unsigned(shift_i))));
                        when others =>
                    end case;
                end if;
            end if;
        end process;
        ready <= '0' when done = '1' and ready_i = '0' else '1';
        done_o <= done;
        ready_o <= ready;
    end generate gen_full_shifter;
    
end architecture rtl;