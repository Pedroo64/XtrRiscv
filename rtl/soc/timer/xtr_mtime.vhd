library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_mtime is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        irq_o : out std_logic
    );
end entity xtr_mtime;

architecture rtl of xtr_mtime is
    signal mtime, mtime_cmp : unsigned(63 downto 0);
begin
    
    p_write : process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mtime_cmp <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mtime_cmp <= (others => '0');
            else
                if xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '1' then
                    case xtr_cmd_i.Adr(3 downto 2) is
                        when "10" =>
                            mtime_cmp(31 downto 0) <= unsigned(xtr_cmd_i.dat);
                        when "11" =>
                            mtime_cmp(63 downto 32) <= unsigned(xtr_cmd_i.dat);
                        when others =>
                    end case;
                end if;
            end if;
        end if;
    end process p_write;
    xtr_rsp_o.rdy <= '1';
    p_read: process(clk_i)
    begin
        if rising_edge(clk_i) then
            xtr_rsp_o.vld <= xtr_cmd_i.vld;
            if xtr_cmd_i.vld = '1' then
                case xtr_cmd_i.Adr(3 downto 2) is
                    when "00" =>
                        xtr_rsp_o.dat <= std_logic_vector(mtime(31 downto 0));
                    when "01" =>
                        xtr_rsp_o.dat <= std_logic_vector(mtime(63 downto 32));
                    when "10" =>
                        xtr_rsp_o.dat <= std_logic_vector(mtime_cmp(31 downto 0));
                    when "11" =>
                        xtr_rsp_o.dat <= std_logic_vector(mtime_cmp(63 downto 32));
                    when others =>
                end case;
            end if;
        end if;
    end process p_read;

    p_mtime: process(clk_i, arst_i)
    begin
        if arst_i = '1' then
            mtime <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mtime <= (others => '0');
            else
                mtime <= mtime + 1;
            end if;
        end if;
    end process p_mtime;
    irq_o <= '1' when mtime >= mtime_cmp else '0';
end architecture rtl;
