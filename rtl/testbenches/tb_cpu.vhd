library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

use work.xtr_def.all;

entity tb_cpu is
end entity tb_cpu;

architecture rtl of tb_cpu is
    constant C_INIT_FILE : string := "C:/Users/Pedro/Documents/Dev/Perso/XtrRiscv/soft/bin/test.mem";
    constant C_MEM_SIZE : integer := 8192 / 4;
    constant C_ADDR_WIDTH : integer := integer(log2(real(C_MEM_SIZE)));
    type ram_type is array (0 to C_MEM_SIZE - 1) of std_logic_vector(31 downto 0);
    impure function ocram_ReadMemFile(FileName : STRING) return ram_type is
        file FileHandle       : TEXT;
        variable CurrentLine  : LINE;
        variable TempWord     : STD_LOGIC_VECTOR(31 downto 0);
        variable Result       : ram_type    := (others => (others => '0'));
    begin
        if FileName /= "none" then
            file_open(FileHandle, FileName,  read_mode);
            for i in 0 to Result'length - 1 loop
                exit when endfile(FileHandle);
                readline(FileHandle, CurrentLine);
                hread(CurrentLine, TempWord);
                Result(i)    := TempWord;
            end loop;
        end if;
        return Result;
    end function;
    signal RAM : ram_type := ocram_ReadMemFile(C_INIT_FILE);
    constant C_CLK_PER                                 : time := 20 ns;
    signal arst                                        : std_logic;
    signal clk                                         : std_logic;

    signal instr_cmd, data_cmd : xtr_cmd_t;
    signal instr_rsp, data_rsp : xtr_rsp_t;

begin

    p_arst : process
    begin
        arst <= '1';
        wait for 63 ns;
        arst <= '0';
        wait;
    end process p_arst;

    p_clk : process
    begin
        clk <= '0';
        wait for C_CLK_PER / 2;
        clk <= '1';
        wait for C_CLK_PER / 2;
    end process p_clk;

    process (clk, arst)
    begin
        if arst = '1' then
            instr_rsp.rdy <= '1';
            instr_rsp.vld <= '0';
            instr_rsp.dat <= (others => '0');
            data_rsp.rdy <= '1';
            data_rsp.vld <= '0';
            data_rsp.dat <= (others => '0');

        elsif rising_edge(clk) then
            instr_rsp.rdy <= '1';
            if instr_cmd.vld = '1' then
                instr_rsp.dat <= RAM(to_integer(unsigned(instr_cmd.adr((C_ADDR_WIDTH - 1) + 2 downto 2))));
                instr_rsp.vld <= '1';
            else
                instr_rsp.vld <= '0';
            end if;
            data_rsp.rdy <= '1';
            if data_cmd.vld = '1' and data_cmd.we = '1' then
                RAM(to_integer(unsigned(data_cmd.adr((C_ADDR_WIDTH - 1) + 2 downto 2)))) <= data_cmd.dat;
                data_rsp.vld <= '1';
            else
                data_rsp.vld <= '0';
            end if;
            if data_cmd.vld = '1' then
                data_rsp.dat <= RAM(to_integer(unsigned(data_cmd.adr((C_ADDR_WIDTH - 1) + 2 downto 2))));
                data_rsp.vld <= '1';
            else
                data_rsp.vld <= '0';
            end if;
        end if;
    end process;

    xtr_cpu_inst : entity work.xtr_cpu
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            instr_cmd_o => instr_cmd, instr_rsp_i => instr_rsp,
            data_cmd_o => data_cmd, data_rsp_i => data_rsp
        );

end architecture rtl;