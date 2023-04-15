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
        signal right0, right1, right2, right3, right4 : std_logic_vector(31 downto 0);
        signal left0, left1, left2, left3, left4 : std_logic_vector(31 downto 0);
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

        right0 <= (16 to 31 => type_i(0) and data_i(31)) & data_i(31 downto 16) when shift_i(4) = '1' else data_i;
        right1 <= (24 to 31 => type_i(0) and data_i(31)) & right0(31 downto  8) when shift_i(3) = '1' else right0;
        right2 <= (28 to 31 => type_i(0) and data_i(31)) & right1(31 downto  4) when shift_i(2) = '1' else right1;
        right3 <= (30 to 31 => type_i(0) and data_i(31)) & right2(31 downto  2) when shift_i(1) = '1' else right2;
        right4 <= (31 to 31 => type_i(0) and data_i(31)) & right3(31 downto  1) when shift_i(0) = '1' else right3;

        left0 <= data_i(15 downto 0) & (0 to 15 => '0') when shift_i(4) = '1' else data_i;
        left1 <=  left0(23 downto 0) & (0 to 7  => '0') when shift_i(3) = '1' else left0;
        left2 <=  left1(27 downto 0) & (0 to 3  => '0') when shift_i(2) = '1' else left1;
        left3 <=  left2(29 downto 0) & (0 to 1  => '0') when shift_i(1) = '1' else left2;
        left4 <=  left3(30 downto 0) & (0 to 0  => '0') when shift_i(0) = '1' else left3;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if start_i = '1' and ready = '1' then
                    if type_i(1) = '0' then
                        data_o <= left4;
                    else
                        data_o <= right4;
                    end if;
                end if;
            end if;
        end process;
        ready <= '0' when done = '1' and ready_i = '0' else '1';
        done_o <= done;
        ready_o <= ready;
    end generate gen_full_shifter;
    
end architecture rtl;