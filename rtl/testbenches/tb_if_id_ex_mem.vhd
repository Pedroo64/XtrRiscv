library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

entity tb_if_id_ex_mem is
end entity tb_if_id_ex_mem;

architecture rtl of tb_if_id_ex_mem is
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
    signal data_cmd_adr, data_cmd_dat, data_rsp_dat : std_logic_vector(31 downto 0);
    signal data_cmd_vld, data_cmd_we : std_logic;
    signal data_cmd_rdy, data_rsp_vld : std_logic;
    -- if
    signal if_en, if_load_pc : std_logic;
    signal if_pc             : std_logic_vector(31 downto 0);
    -- if -> id
    signal if_id_pc, if_id_instr : std_logic_vector(31 downto 0);
    signal if_id_instr_vld : std_logic;
    -- id
    signal id_en, id_decode_rdy : std_logic;
    signal id_rs1_adr, id_rs2_adr : std_logic_vector(4 downto 0);
    -- id -> ex
    signal id_ex_vld, id_ex_mem_vld : std_logic;
    signal id_ex_opcode : std_logic_vector(6 downto 0);
    signal id_ex_rd_adr : std_logic_vector(4 downto 0);
    signal id_ex_funct3 : std_logic_vector(2 downto 0);
    signal id_ex_funct7 : std_logic_vector(6 downto 0);
    signal id_ex_immediate, id_ex_rs1_dat, id_ex_rs2_dat, id_ex_pc : std_logic_vector(31 downto 0);
    -- ex
    signal ex_en, ex_execute_rdy : std_logic;
    -- ex -> mem
    signal ex_mem_vld, ex_mem_we : std_logic;
    signal ex_mem_adr, ex_mem_dat : std_logic_vector(31 downto 0);
    signal ex_mem_siz : std_logic_vector(1 downto 0);
    signal ex_mem_rd_we : std_logic;
    signal ex_mem_rd_adr : std_logic_vector(4 downto 0);
    -- ex -> wb
    -- mem
    signal mem_en : std_logic;
    signal mem_rdy : std_logic;
    -- wb
    signal wb_rdy : std_logic;
    signal wb_rdy_dly : std_logic_vector(1 downto 0);
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
            wb_rdy <= '1';
            wb_rdy_dly <= (others => '1');
            --mem_rdy <= '1';
            data_cmd_rdy <= '1';
            data_rsp_vld <= '0';
            data_rsp_dat <= (others => '0');
        elsif rising_edge(clk) then
            instr_cmd_rdy    <= '1';
            --ex_execute_rdy <= '1';
            --en <= t_en;
            if instr_cmd_vld = '1' then
                instr_rsp_vld <= '1';
                instr_rsp_dat <= ram(to_integer(unsigned(instr_cmd_adr(4 + 2 downto 2))));
                --instr_rsp_dat <= std_logic_vector(unsigned(instr_rsp_dat) + 1);
            else
                instr_rsp_vld <= '0';
            end if;
            if data_cmd_vld = '1' then
                data_rsp_vld <= '1';
                data_rsp_dat <= ram(to_integer(unsigned(data_cmd_adr(4 + 2 downto 2))));
            else
                data_rsp_vld <= '0';
            end if;
            if unsigned(instr_cmd_adr(7 downto 0)) = 16#40# and instr_cmd_vld = '1' then
                if_load_pc <= '1';
                if_pc      <= std_logic_vector(unsigned(if_pc) + x"100");
            else
                if_load_pc <= '0';
            end if;
            if unsigned(instr_cmd_adr(7 downto 0)) = 16#0C# and instr_cmd_vld = '1' and wb_rdy = '1' then
                wb_rdy <= '0';
                wb_rdy_dly(0) <= '1';
            elsif (unsigned(instr_cmd_adr(7 downto 0)) = 16#34# or unsigned(instr_cmd_adr(7 downto 0)) = 16#38#) and wb_rdy_dly(1) = '1' then
                wb_rdy <= '0';
                wb_rdy_dly(0) <= '0';
            else
                wb_rdy <= '1';
                wb_rdy_dly(0) <= '1';
            end if;
            if unsigned(id_ex_pc(7 downto 0)) = 16#14# and data_cmd_rdy = '1' then
                data_cmd_rdy <= '0';
            else
                data_cmd_rdy <= '1';
            end if;
            if unsigned(instr_cmd_adr(7 downto 0)) = 16#20# and instr_cmd_vld = '1' and if_en = '1' then
                if_en <= '0';
            else
                if_en <= '1';
            end if;
            wb_rdy_dly(1) <= wb_rdy_dly(0);
        end if;
    end process;
    --mem_rdy <= '1';
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
            opcode_o => id_ex_opcode, rs1_adr_o => id_rs1_adr, rs2_adr_o => id_rs2_adr, rd_adr_o => id_ex_rd_adr,
            funct3 => id_ex_funct3, funct7 => id_ex_funct7, immediate_o => id_ex_immediate,
            pc_o => id_ex_pc, vld_o => id_ex_vld, mem_vld_o => id_ex_mem_vld);

    regfile_inst : entity work.regfile
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            rs1_adr_i => id_rs1_adr, rs1_dat_o => id_ex_rs1_dat, rs2_adr_i => id_rs2_adr, rs2_dat_o => id_ex_rs2_dat,
            rd_adr_i => (others => '0'), rd_we_i => '0', rd_dat_i => (others => '0'));
          
    ex_en <= '1';
    u_ex : entity work.execute
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            en_i => ex_en, vld_i => id_ex_vld, mem_vld_i => id_ex_mem_vld, mem_rdy_i => mem_rdy, wb_rdy_i => wb_rdy, rdy_o => ex_execute_rdy,
            pc_i => id_ex_pc, opcode_i => id_ex_opcode, immediate_i => id_ex_immediate, funct3_i => id_ex_funct3, funct7_i => id_ex_funct7,
            rs1_dat_i => id_ex_rs1_dat, rs2_dat_i => id_ex_rs2_dat,
            rd_adr_i => id_ex_rd_adr, 
            rd_adr_o => open, rd_we_o => open, rd_dat_o => open,
            load_pc_o => open, pc_o => open,
            mem_rd_adr_o => ex_mem_rd_adr,
            mem_cmd_adr_o => ex_mem_adr, mem_cmd_vld_o => ex_mem_vld, mem_cmd_we_o => ex_mem_we, mem_cmd_dat_o => ex_mem_dat, mem_cmd_siz_o => ex_mem_siz);
    mem_en <= '1';
    u_mem : entity work.memory
        port map (
            arst_i => arst, clk_i => clk, srst_i => '0',
            en_i => mem_en,
            adr_i => ex_mem_adr, vld_i => ex_mem_vld, we_i => ex_mem_we, siz_i => ex_mem_siz, dat_i => ex_mem_dat,
            rd_adr_i => ex_mem_rd_adr, rd_adr_o => ex_mem_rd_adr, rd_we_o => ex_mem_rd_we,
            cmd_adr_o => data_cmd_adr, cmd_vld_o => data_cmd_vld, cmd_we_o => data_cmd_we, cmd_dat_o => data_cmd_dat, cmd_rdy_i => data_cmd_rdy,
            rsp_vld_i => data_rsp_vld, rsp_dat_i => data_rsp_dat, rdy_o => mem_rdy);
          
end architecture rtl;