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
        ecall_i : in std_logic;
        mret_i : in std_logic;
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic;
        exception_valid_o : out std_logic;
        exception_taken_i : in std_logic;
        cause_external_irq_o : out std_logic;
        cause_timer_irq_o : out std_logic
    );
end entity interrupt_handler;

architecture rtl of interrupt_handler is
    signal on_irq, d_on_irq : std_logic;
    signal irq_en, external_irq_en, timer_irq_en : std_logic;
    signal exception_valid : std_logic;
    signal d_ecall, d_ext_irq, d_timer_irq : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            on_irq <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                on_irq <= '0';
            else
                if on_irq = '0' then
                    if irq_en = '1' and ((external_irq_i and external_irq_en) = '1' or (timer_irq_i and timer_irq_en) = '1') then
                        on_irq <= '1';
                    elsif ecall_i = '1' then
                        on_irq <= '1';
                    end if;
                elsif mret_i = '1' then
                    on_irq <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            d_on_irq <= on_irq;
            d_ext_irq <= external_irq_i and external_irq_en;
            d_timer_irq <= timer_irq_i and timer_irq_en;
        end if;
    end process;

    irq_en <= mstatus_i(CSR_MSTATUS_MIE);
    external_irq_en <= mie_i(CSR_MIE_MEIE);
    timer_irq_en <= mie_i(CSR_MIE_MTIE);

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            exception_valid <= '0';
            cause_external_irq_o <= '0';
            cause_timer_irq_o <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                exception_valid <= '0';
                cause_external_irq_o <= '0';
                cause_timer_irq_o <= '0';
            else
                if on_irq = '1' and d_on_irq = '0' then
                    if d_ext_irq = '1' then
                        exception_valid <= '1';
                        cause_external_irq_o <= '1';
                    elsif d_timer_irq = '1' then
                        exception_valid <= '1';
                        cause_timer_irq_o <= '1';
                    end if;
                elsif exception_taken_i = '1' then
                    exception_valid <= '0';
                    cause_external_irq_o <= '0';
                    cause_timer_irq_o <= '0';
                end if;
            end if;
        end if;
    end process;

    exception_valid_o <= 
        '1' when exception_valid = '1' and exception_taken_i = '0' else
        '0';
end architecture rtl;