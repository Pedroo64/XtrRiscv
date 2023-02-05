library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity control_unit is
    generic (
        G_WRITEBACK_BYPASS : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        decode_valid_i : in std_logic;
        decode_opcode_i : in opcode_t;
        decode_rs1_adr_i : in std_logic_vector(4 downto 0);
        decode_rs2_adr_i : in std_logic_vector(4 downto 0);
        decode_rd_adr_i : in std_logic_vector(4 downto 0);
        decode_rd_we_i : in std_logic;
        decode_funct3_i : in std_logic_vector(2 downto 0);
        execute_ready_i : in std_logic;
        execute_branch_i : in std_logic;
        writeback_rd_adr_i : in std_logic_vector(4 downto 0);
        writeback_rd_we_i : in std_logic;
        writeback_branch_i : in std_logic;
        fetch_reset_o : out std_logic;
        decode_reset_o : out std_logic;
        execute_enable_o : out std_logic;
        rs1_writeback_bypass_o : out std_logic;
        rs2_writeback_bypass_o : out std_logic
    );
end entity control_unit;

architecture rtl of control_unit is
    signal registers_mutex : std_logic_vector(31 downto 0);
    signal d_execute_branch : std_logic;
    signal op_use_rs1, op_use_rs2 : std_logic;
    signal d_writeback_rd_we : std_logic;
    signal d_writeback_rd_adr : std_logic_vector(4 downto 0);
    signal rs1_writeback_bypass, rs2_writeback_bypass : std_logic;
begin
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            d_writeback_rd_we <= writeback_rd_we_i;
            d_writeback_rd_adr <= writeback_rd_adr_i;
        end if;
    end process;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            registers_mutex <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                registers_mutex <= (others => '0');
            else
                for i in 1 to registers_mutex'length - 1 loop
                    if decode_valid_i = '1' and decode_rd_we_i = '1' and execute_ready_i = '1' and unsigned(decode_rd_adr_i) = i then
                        registers_mutex(i) <= '1';
                    elsif writeback_rd_we_i = '1' and unsigned(writeback_rd_adr_i) = i then
                        registers_mutex(i) <= '0';
                    end if;
                end loop;
                d_execute_branch <= execute_branch_i;
            end if;
        end if;
    end process;
    
    fetch_reset_o <= '0';
    decode_reset_o <= execute_branch_i or d_execute_branch;
    execute_enable_o <= 
        '0' when execute_branch_i = '1' else
        '0' when decode_valid_i = '1' and decode_rd_we_i = '1' and registers_mutex(to_integer(unsigned(decode_rd_adr_i))) = '1' else
        '0' when decode_valid_i = '1' and op_use_rs1 = '1' and registers_mutex(to_integer(unsigned(decode_rs1_adr_i))) = '1' and rs1_writeback_bypass = '0' else
        '0' when decode_valid_i = '1' and op_use_rs2 = '1' and registers_mutex(to_integer(unsigned(decode_rs2_adr_i))) = '1' and rs2_writeback_bypass = '0' else
        '1';

    op_use_rs1 <= 
        '1' when (decode_opcode_i.reg_reg or decode_opcode_i.load or decode_opcode_i.reg_imm or decode_opcode_i.jalr or decode_opcode_i.store or decode_opcode_i.branch) = '1' else
        '1' when decode_opcode_i.sys = '1' and decode_funct3_i(2) = '0' else
        '0';

    op_use_rs2 <=
        '1' when (decode_opcode_i.reg_reg or decode_opcode_i.store or decode_opcode_i.branch) = '1' else
        '0';

    rs1_writeback_bypass <= 
        '1' when writeback_rd_adr_i = decode_rs1_adr_i and unsigned(writeback_rd_adr_i) /= 0 and writeback_rd_we_i = '1' and G_WRITEBACK_BYPASS = TRUE else
        '0';
    rs2_writeback_bypass <= 
        '1' when writeback_rd_adr_i = decode_rs2_adr_i and unsigned(writeback_rd_adr_i) /= 0 and writeback_rd_we_i = '1' and G_WRITEBACK_BYPASS = TRUE else
        '0';

    rs1_writeback_bypass_o <= rs1_writeback_bypass;
    rs2_writeback_bypass_o <= rs2_writeback_bypass;
end architecture rtl;