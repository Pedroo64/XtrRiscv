library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_tx is
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        baud : in std_logic_vector(15 downto 0);
        tx_vld_i : in std_logic;
        tx_dat_i : in std_logic_vector(7 downto 0);
        tx_o : out std_logic;
        rdy_o : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
    type UART_ST is (ST_IDLE, ST_START, ST_DATA, ST_STOP);
    signal current_st : UART_ST;
    signal baud_cnt : unsigned(16 downto 0);
    signal bit_cnt, tx_dat : std_logic_vector(7 downto 0);
    signal tx, baud_en : std_logic;
begin
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if current_st /= ST_IDLE then
                baud_cnt <= ('0' & baud_cnt(baud_cnt'left - 1 downto 0)) + ('0' & unsigned(baud));
            else 
                baud_cnt <= ('0' & unsigned(baud));
            end if;
        end if;
    end process;
    baud_en <= baud_cnt(baud_cnt'left);
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            current_st <= ST_IDLE;
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                current_st <= ST_IDLE;
            else
                case current_st is
                    when ST_IDLE =>
                        if tx_vld_i = '1' then
                            current_st <= ST_START;
                        end if;
                    when ST_START =>
                        if baud_en = '1' then
                            current_st <= ST_DATA;
                        end if;
                    when ST_DATA =>
                        if baud_en = '1' and bit_cnt(bit_cnt'left) = '1' then
                            current_st <= ST_STOP;
                        end if;
                    when ST_STOP => 
                        if baud_en = '1' then
                            current_st <= ST_IDLE;
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
            if current_st /= ST_DATA then
                bit_cnt <= std_logic_vector(to_unsigned(1, bit_cnt'length));
            end if;
            case current_st is
                when ST_IDLE => 
                    tx <= '1';
                when ST_START =>
                    tx <= '0';
                when ST_DATA =>
                    tx <= tx_dat(0);
                    if baud_en = '1' then
                        tx_dat <= '0' & tx_dat(tx_dat'left downto 1);
                        bit_cnt <= bit_cnt(bit_cnt'left - 1 downto 0) & '0';
                    end if;
                when ST_STOP =>
                    tx <= '1';
                when others =>
            end case;
        end if;
    end process;
    
    rdy_o <= '0' when current_st /= ST_IDLE else '1';

end architecture rtl;