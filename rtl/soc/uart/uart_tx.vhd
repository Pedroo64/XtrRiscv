library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_tx is
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        baud_i : in std_logic_vector(23 downto 0);
        tx_vld_i : in std_logic;
        tx_dat_i : in std_logic_vector(7 downto 0);
        tx_o : out std_logic;
        rdy_o : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
    type uart_st is (st_idle, st_start, st_data, st_stop);
    signal current_st : uart_st;
    signal baud_cnt : unsigned(24 downto 0);
    signal bit_cnt, tx_dat : std_logic_vector(7 downto 0);
    signal tx, baud_en : std_logic;
begin
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if current_st /= st_idle then
                baud_cnt <= ('0' & baud_cnt(baud_cnt'left - 1 downto 0)) + ('0' & unsigned(baud_i));
            else 
                baud_cnt <= (others => '0');
            end if;
        end if;
    end process;
    baud_en <= baud_cnt(baud_cnt'left);
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
                        if tx_vld_i = '1' then
                            current_st <= st_start;
                        end if;
                    when st_start =>
                        if baud_en = '1' then
                            current_st <= st_data;
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
            if tx_vld_i = '1' then
                tx_dat <= tx_dat_i;
            end if;
            if current_st /= st_data then
                bit_cnt <= std_logic_vector(to_unsigned(1, bit_cnt'length));
            end if;
            case current_st is
                when st_idle => 
                    tx <= '1';
                when st_start =>
                    tx <= '0';
                when st_data =>
                    tx <= tx_dat(0);
                    if baud_en = '1' then
                        tx_dat <= '0' & tx_dat(tx_dat'left downto 1);
                        bit_cnt <= bit_cnt(bit_cnt'left - 1 downto 0) & '0';
                    end if;
                when st_stop =>
                    tx <= '1';
                when others =>
            end case;
        end if;
    end process;
    
    rdy_o <= '0' when current_st /= st_idle else '1';
    tx_o <= tx;

end architecture rtl;
