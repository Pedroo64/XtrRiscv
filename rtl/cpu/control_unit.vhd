library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity control_unit is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        decode_valid_i : in std_logic;
        decode_opcode_i : in std_logic_vector(6 downto 0);
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
        execute_enable_o : out std_logic
    );
end entity control_unit;

architecture rtl of control_unit is
    signal registers_mutex : std_logic_vector(31 downto 0);
    signal d_execute_branch : std_logic;
    signal op_use_rs1, op_use_rs2 : std_logic;
    signal d_writeback_rd_we : std_logic;
    signal d_writeback_rd_adr : std_logic_vector(4 downto 0);
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
                if decode_valid_i = '1' and decode_rd_we_i = '1' and execute_ready_i = '1' then
                    if unsigned(decode_rd_adr_i) /= 0 then
                        registers_mutex(to_integer(unsigned(decode_rd_adr_i))) <= '1';
                    end if;
                end if;
                if d_writeback_rd_we = '1' then
                    registers_mutex(to_integer(unsigned(d_writeback_rd_adr))) <= '0';
                end if;
                d_execute_branch <= execute_branch_i;
            end if;
        end if;
    end process;
    
    fetch_reset_o <= '0';
    decode_reset_o <= execute_branch_i or d_execute_branch;
    execute_enable_o <= 
        '0' when execute_branch_i = '1' else
        '0' when decode_valid_i = '1' and decode_rd_we_i = '1' and registers_mutex(to_integer(unsigned(decode_rd_adr_i))) = '1' else
        '0' when decode_valid_i = '1' and op_use_rs1 = '1' and registers_mutex(to_integer(unsigned(decode_rs1_adr_i))) = '1' else
        '0' when decode_valid_i = '1' and op_use_rs2 = '1' and registers_mutex(to_integer(unsigned(decode_rs2_adr_i))) = '1' else
        '1';

    op_use_rs1 <= 
        '1' when decode_opcode_i = RV32I_OP_REG_REG else
        '1' when decode_opcode_i = RV32I_OP_LOAD else
        '1' when decode_opcode_i = RV32I_OP_REG_IMM else
        '1' when decode_opcode_i = RV32I_OP_SYS and decode_funct3_i(2) = '0' else
        '1' when decode_opcode_i = RV32I_OP_JALR else
        '1' when decode_opcode_i = RV32I_OP_STORE else
        '1' when decode_opcode_i = RV32I_OP_BRANCH else
        '0';

    op_use_rs2 <= 
        '1' when decode_opcode_i = RV32I_OP_REG_REG else
        '1' when decode_opcode_i = RV32I_OP_STORE else
        '1' when decode_opcode_i = RV32I_OP_BRANCH else
        '0';


--        RV32I_OP_REG_REG -- R
--        RV32I_OP_LOAD -- I
--        RV32I_OP_REG_IMM -- I
--        RV32I_OP_SYS -- I
--        RV32I_OP_JALR -- I
--        RV32I_OP_STORE -- S
--        RV32I_OP_BRANCH -- B
--        RV32I_OP_LUI -- U
--        RV32I_OP_AUIPC -- U
--        RV32I_OP_JAL -- J

end architecture rtl;