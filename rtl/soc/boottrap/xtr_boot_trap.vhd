library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.xtr_def.all;

entity xtr_boot_trap is
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        xtr_cmd_i : in xtr_cmd_t;
        xtr_rsp_o : out xtr_rsp_t;
        baud_en_i : in std_logic;
        rx_vld_i : in std_logic;
        rx_dat_i : in std_logic_vector(7 downto 0);
        trap_o : out std_logic
    );
end entity xtr_boot_trap;

architecture rtl of xtr_boot_trap is
    signal rst_from_cpu : std_logic;
    signal trap_rst, trap_rom, trap_ram, trap_event : std_logic;
    signal program_vect : std_logic_vector(31 downto 2);
    signal rom_flag, ram_flag : std_logic;
    signal d_rom_flag, d_ram_flag : std_logic;
begin
    trap_rst <= '1' when trap_event = '1' and rx_dat_i = x"30" else '0';
    trap_rom <= '1' when trap_event = '1' and rx_dat_i = x"31" else '0';
    trap_ram <= '1' when trap_event = '1' and rx_dat_i = x"32" else '0';
    trap_o <= trap_rst or trap_rom or trap_ram or rst_from_cpu;
    pWriteMem: process(clk_i, arst_i)
    begin
        if arst_i = '1' then
            program_vect <= (others => '0');
            rom_flag <= '0';
            ram_flag <= '0';
            rst_from_cpu <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                program_vect <= (others => '0');
                rom_flag <= '0';
                ram_flag <= '0';
                rst_from_cpu <= '0';
            else
                if xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '1' then
                    program_vect <= xtr_cmd_i.dat(31 downto 2);
                    rst_from_cpu <= '1';
                else
                    rst_from_cpu <= '0';
                end if;
                if trap_rom = '1' then
                    rom_flag <= '1';
                elsif xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '0' then
                    rom_flag <= '0';
                end if;
                if trap_ram = '1' then
                    ram_flag <= '1';
                elsif xtr_cmd_i.vld = '1' and xtr_cmd_i.we = '0' then
                    ram_flag <= '0';
                end if;
            end if;
        end if;
    end process pWriteMem;
    xtr_rsp_o.rdy <= '1';
    xtr_rsp_o.dat <= program_vect & d_ram_flag & d_rom_flag;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            xtr_rsp_o.vld <= xtr_cmd_i.vld;
            d_rom_flag <= rom_flag;
            d_ram_flag <= ram_flag;
        end if;
    end process;
    u_boot_trap : entity work.boot_trap
        port map (
            arst_i => arst_i, clk_i => clk_i, srst_i => srst_i,
            baud_en_i => baud_en_i, rx_vld_i  => rx_vld_i, rx_dat_i => rx_dat_i,
            trap_o => trap_event);

end architecture rtl;
