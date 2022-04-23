library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity boot_trap is
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        baud_en_i : in std_logic;
        rx_vld_i : in std_logic;
        rx_dat_i : in std_logic_vector(7 downto 0);
        trap_o : out std_logic
    );
end entity boot_trap;

architecture rtl of boot_trap is
    constant C_CHAR_SEQ : std_logic_vector(7 downto 0) := x"2B";
    constant TIMER_CNT_LOAD_VALUE : integer := 8*3;
    type boot_trap_st is (st_idle, st_type);
    signal current_st : boot_trap_st;
    signal word_cnt : std_logic_vector(2 downto 0);
    signal timer_cnt : std_logic_vector(8 downto 0);
    signal timeout : std_logic;
begin
    
    pFsm: process(clk_i, arst_i)
    begin
        if arst_i = '1' then
            current_st <= st_idle;
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                current_st <= st_idle;
            else
                case current_st is
                    when st_idle =>
                        if word_cnt(word_cnt'left) = '1' and rx_vld_i = '1' and rx_dat_i = C_CHAR_SEQ then
                            current_st <= st_type;
                        end if;
                    when st_type =>
                        if rx_vld_i = '1' or timeout = '1' then
                            current_st <= st_idle;
                        end if;
                    when others =>
                end case;
            end if;
        end if;
    end process pFsm;
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            timer_cnt <= std_logic_vector(to_unsigned(TIMER_CNT_LOAD_VALUE, timer_cnt'length)); -- 3 bytes before setting timeout
            word_cnt  <= "001";
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                timer_cnt <= std_logic_vector(to_unsigned(TIMER_CNT_LOAD_VALUE, timer_cnt'length));
                word_cnt  <= "001";
            else
                if rx_vld_i = '1' or timeout = '1' then
                    timer_cnt <= std_logic_vector(to_unsigned(TIMER_CNT_LOAD_VALUE, timer_cnt'length));
                elsif baud_en_i = '1' then
                    timer_cnt <= std_logic_vector(unsigned(timer_cnt) - "1");
                end if;
                if current_st = st_idle then
                    if rx_vld_i = '1' then
                        word_cnt <= word_cnt(1 downto 0) & word_cnt(2);
                    elsif timeout = '1' then
                        word_cnt <= "001";
                    end if;
                end if;
            end if;
        end if;
    end process;
    timeout <= '1' when unsigned(timer_cnt) = 0 and baud_en_i = '1' else '0';
    trap_o <= '1' when current_st = st_type and rx_vld_i = '1' else '0';

end architecture rtl;
