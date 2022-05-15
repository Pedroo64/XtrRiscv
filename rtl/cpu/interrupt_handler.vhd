library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.csr_def.all;

entity interrupt_handler is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        mstatus_i : in std_logic_vector(31 downto 0);
        mie_i : in std_logic_vector(31 downto 0);
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic;
        exception_valid_o : out std_logic;
        exception_taken_i : in std_logic;
        cause_external_irq_o : out std_logic;
        cause_timer_irq_o : out std_logic
    );
end entity interrupt_handler;

architecture rtl of interrupt_handler is
    type interrupt_handler_st is (st_idle, st_external, st_timer);
    signal current_st : interrupt_handler_st;
    signal irq_en, external_irq_en, timer_irq_en : std_logic;
    signal exception_valid : std_logic;
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
                        if irq_en = '1' then
                            if (external_irq_i and external_irq_en) = '1' then
                                current_st <= st_external;
                            elsif (timer_irq_i and timer_irq_en) = '1' then
                                current_st <= st_timer;
                            end if;
                        end if;
                    when st_external | st_timer =>
                        if exception_taken_i = '1' then
                            current_st <= st_idle;
                        end if;
                    when others =>
                end case;
            end if;
        end if;
    end process;

    irq_en <= mstatus_i(CSR_MSTATUS_MIE);
    external_irq_en <= mie_i(CSR_MIE_MEIE);
    timer_irq_en <= mie_i(CSR_MIE_MTIE);

    exception_valid <= 
        '1' when current_st = st_external or current_st = st_timer else
        '0';

    exception_valid_o <= 
        '1' when exception_valid = '1' and exception_taken_i = '0' else
        '0';

    cause_external_irq_o <= 
        '1' when current_st = st_external else
        '0';
    cause_timer_irq_o <= 
        '1' when current_st = st_timer else
        '0';

end architecture rtl;