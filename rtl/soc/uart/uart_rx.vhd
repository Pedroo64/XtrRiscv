library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_rx is
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        baud_i : in std_logic_vector(15 downto 0);
        rx_vld_o : out std_logic;
        rx_dat_o : out std_logic_vector(7 downto 0);
        rx_i : in std_logic
    );
end entity uart_rx;

architecture rtl of uart_rx is
    type uart_st is (st_idle, st_start, st_data, st_stop);
    signal current_st : uart_st;
    signal baud_cnt : unsigned(16 downto 0);
    signal bit_cnt, rx_dat : std_logic_vector(7 downto 0);
    signal rx, baud_clk, baud_en : std_logic;
begin
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            rx <= rx_i;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if current_st /= st_idle then
                baud_cnt <= ('0' & baud_cnt(baud_cnt'left - 1 downto 0)) + ('0' & unsigned(baud_i));
            else 
                baud_cnt <= ('0' & unsigned(baud_i));
            end if;
            if current_st /= st_idle then
                if baud_cnt(baud_cnt'left) = '1' then
                    baud_clk <= not baud_clk;
                end if;
            else
                baud_clk <= '0';
            end if;
        end if;
    end process;
    baud_en <= '1' when baud_clk = '0' and baud_cnt(baud_cnt'left) = '1' else '0';
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
                        if rx = '0' then
                            current_st <= st_start;
                        end if;
                    when st_start =>
                        if baud_en = '1' then
                            if rx = '0' then
                                current_st <= st_data;
                            else
                                current_st <= st_idle;
                            end if;
                        end if;
                    when st_data =>
                        if baud_en = '1' and bit_cnt(bit_cnt'left) = '1' then
                            current_st <= st_stop;
                        end if;
                    when st_stop =>
                        if baud_en = '1' then
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
            rx_vld_o <= '0';
            if current_st /= st_data then
                bit_cnt <= std_logic_vector(to_unsigned(1, bit_cnt'length));
            end if;
            case current_st is
                when st_data =>
                    if baud_en = '1' then
                        rx_dat <= rx & rx_dat(rx_dat'left downto 1);
                        bit_cnt <= bit_cnt(bit_cnt'left - 1 downto 0) & '0';
                    end if;
                when st_stop =>
                    if baud_en = '1' and rx = '1' then
                        rx_vld_o <= '1';
                    end if;
                when others =>
            end case;
        end if;
    end process;
    rx_dat_o <= rx_dat;
end architecture rtl;