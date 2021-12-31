library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

entity tb_if_id is
end entity tb_if_id;

architecture rtl of tb_if_id is
    constant C_INIT_FILE : string := "C:/Users/Pedro/Documents/Dev/Perso/XtrRiscv/soft/bin/test.mem";
    type ram_type is array (0 to 31) of std_logic_vector(31 downto 0);
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
    signal instr_cmd_adr, instr_rsp_dat                : std_logic_vector(31 downto 0);
    signal instr_cmd_vld, instr_cmd_rdy, instr_rsp_vld : std_logic;
    -- if
    signal if_en, if_load_pc : std_logic;
    signal if_pc             : std_logic_vector(31 downto 0);
    -- if -> id
    signal if_id_pc, if_id_instr : std_logic_vector(31 downto 0);
    signal if_id_instr_vld : std_logic;
    -- id
    signal id_en, id_decode_rdy : std_logic;
    -- id -> ex
    -- ex
    signal ex_execute_rdy : std_logic;
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
            instr_cmd_rdy    <= '1';
            instr_rsp_vld    <= '0';
            instr_rsp_dat    <= (others => '0');
            if_load_pc    <= '0';
            if_pc         <= (others => '0');
            if_en         <= '0';
            ex_execute_rdy <= '1';
        elsif rising_edge(clk) then
            instr_cmd_rdy    <= '1';
            ex_execute_rdy <= '1';
            --en <= t_en;
            if instr_cmd_vld = '1' then
                instr_rsp_vld <= '1';
                instr_rsp_dat <= ram(to_integer(unsigned(instr_cmd_adr(4 + 2 downto 2))));
                --instr_rsp_dat <= std_logic_vector(unsigned(instr_rsp_dat) + 1);
            else
                instr_rsp_vld <= '0';
            end if;
            if unsigned(instr_cmd_adr(7 downto 0)) = 16#40# and instr_cmd_vld = '1' then
                if_load_pc <= '1';
                if_pc      <= std_logic_vector(unsigned(if_pc) + x"100");
            else
                if_load_pc <= '0';
            end if;
            if unsigned(instr_cmd_adr(7 downto 0)) = 16#10# and instr_cmd_vld = '1' and ex_execute_rdy = '1' then
                ex_execute_rdy <= '0';
            elsif (unsigned(instr_cmd_adr(7 downto 0)) = 16#34# or unsigned(instr_cmd_adr(7 downto 0)) = 16#38#) and instr_cmd_vld = '1' then
                ex_execute_rdy <= '0';
            else
                ex_execute_rdy <= '1';
            end if;
            if unsigned(instr_cmd_adr(7 downto 0)) = 16#20# and instr_cmd_vld = '1' and if_en = '1' then
                if_en <= '0';
            elsif unsigned(instr_cmd_adr(7 downto 0)) = 16#30# and instr_cmd_vld = '1' and if_en = '1' then
                if_en <= '0';
            else
                if_en <= '1';
            end if;
        end if;
    end process;
    u_if : entity work.instruction_fecth
        port map(
            arst_i => arst, clk_i => clk, srst_i => '0',
            en_i => if_en,
            load_pc_i => if_load_pc, pc_i => if_pc,
            cmd_adr_o => instr_cmd_adr, cmd_vld_o => instr_cmd_vld, cmd_rdy_i => instr_cmd_rdy, rsp_dat_i => instr_rsp_dat, rsp_vld_i => instr_rsp_vld,
            pc_o => if_id_pc, instr_o => if_id_instr, instr_vld_o => if_id_instr_vld, decode_rdy_i => id_decode_rdy);

    id_en <= '1';
    u_id : entity work.instruction_decode
        port map(
            arst_i => arst, clk_i => clk, srst_i => '0',
            en_i => id_en, decode_rdy_o => id_decode_rdy, execute_rdy_i => ex_execute_rdy,
            pc_i => if_id_pc, instr_i => if_id_instr, instr_vld_i => if_id_instr_vld,
            opcode_o => open, rs1_adr_o => open, rs2_adr_o => open, rd_adr_o => open,
            funct3 => open, funct7 => open, immediate_o => open,
            decode_vld_o => open);

end architecture rtl;