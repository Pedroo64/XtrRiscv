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
        ready_o : out std_logic
    );
end entity shifter;

architecture rtl of shifter is
    signal data : std_logic_vector(31 downto 0);
    signal shift_type : std_logic_vector(1 downto 0);
    signal shift_cnt : unsigned(4 downto 0);
begin
    gen_light_shifter: if G_FULL_BARREL_SHIFTER = FALSE generate
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                shift_cnt <= (others => '0');
            elsif rising_edge(clk_i) then
                if srst_i = '1' then
                    shift_cnt <= (others => '0');
                else
                    if start_i = '1' then
                        shift_cnt <= unsigned(shift_i);
                    elsif shift_cnt /= 0 then
                        shift_cnt <= shift_cnt - 1;
                    end if;
                end if;
            end if;
        end process;
    
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if start_i = '1' then
                    data <= data_i;
                    shift_type <= type_i;
                elsif shift_cnt /= 0 then
                    if shift_type(1) = '1' then
                        data <= (shift_type(0) and data(31)) & data(31 downto 1);
                    else
                        data <= data(30 downto 0) & '0';
                    end if;
                end if;
            end if;
        end process;
    
        ready_o <= '1' when shift_cnt = 0 else '0';
        data_o <= data;
        done_o <= '1';
    end generate gen_light_shifter;

    gen_full_shifter: if G_FULL_BARREL_SHIFTER = TRUE generate
        signal right0, right1, right2, right3, right4 : std_logic_vector(31 downto 0);
        signal left0, left1, left2, left3, left4 : std_logic_vector(31 downto 0);
    begin

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
				if type_i(1) = '0' then
					data_o <= left4;
				else
					data_o <= right4;
				end if;
            end if;
        end process;
        done_o <= '1';
        ready_o <= '1';
    end generate gen_full_shifter;


end architecture rtl;