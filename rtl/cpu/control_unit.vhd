library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity control_unit is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        opcode_i : in std_logic_vector(6 downto 0);
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        ex_mem_rd_adr_i : in std_logic_vector(4 downto 0);
        ex_mem_rd_we_i : in std_logic;
        ex_rd_adr_i : in std_logic_vector(4 downto 0);
        ex_rd_we_i : in std_logic;
        wb_rd_adr_i : in std_logic_vector(4 downto 0);
        wb_rd_we_i : in std_logic;
        ex_load_pc_i : in std_logic;
        wb_load_pc_i : in std_logic;
        csr_load_pc_i : in std_logic;
        branching_o : out std_logic;
        if_en_o : out std_logic;
        if_rst_o : out std_logic;
        id_en_o : out std_logic;
        id_rst_o : out std_logic;
        ex_en_o : out std_logic;
        ex_rst_o : out std_logic
    );
end entity control_unit;

architecture rtl of control_unit is
    signal reg_mutex : std_logic_vector(31 downto 0);
    signal branching, d_branching : std_logic;
    signal op_use_rs1, op_use_rs2, op_csr : std_logic;
    signal rs1_adr, rs2_adr : std_logic_vector(4 downto 0);
    signal d_wb_rd_we : std_logic;
    signal d_wb_rd_adr : std_logic_vector(4 downto 0);
    signal ex_en : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            reg_mutex <= (others => '0');
            branching <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                reg_mutex <= (others => '0');
                branching <= '0';
            else 
                if d_wb_rd_we = '1' then
                    reg_mutex(to_integer(unsigned(d_wb_rd_adr))) <= '0';
                end if;
                if ex_mem_rd_we_i = '1' then
                    reg_mutex(to_integer(unsigned(ex_mem_rd_adr_i))) <= '1';
                end if;
                if ex_rd_we_i = '1' then
                    reg_mutex(to_integer(unsigned(ex_rd_adr_i))) <= '1';
                end if;
                if ex_load_pc_i = '1' or csr_load_pc_i = '1' then
                    branching <= '1';
                elsif wb_load_pc_i = '1' then
                    branching <= '0';
                end if;
            end if;
        end if;
    end process;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            rs1_adr <= (others => '0');
            rs2_adr <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                rs1_adr <= (others => '0');
                rs2_adr <= (others => '0');
            else
                rs1_adr <= rs1_adr_i;
                rs2_adr <= rs2_adr_i;
            end if;
        end if;
    end process;
--    process (clk_i, arst_i)
--    begin
--        if arst_i = '1' then
--            ex_en <= '1';
--        elsif rising_edge(clk_i) then
--            if srst_i = '1' then
--                ex_en <= '1';
--            else
--                if reg_mutex(to_integer(unsigned(rs1_adr))) = '1' and op_use_rs1 = '1' then
--                    ex_en <= '0';
--                elsif reg_mutex(to_integer(unsigned(rs2_adr))) = '1' and op_use_rs2 = '1' then
--                    ex_en <= '0';
--                else
--                    ex_en <= '1';
--                end if;
--            end if;
--        end if;
--    end process;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            d_wb_rd_we <= '0';
            d_branching <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                d_wb_rd_we <= '0';
                d_branching <= '0';
            else
                d_wb_rd_we <= wb_rd_we_i;
                d_wb_rd_adr <= wb_rd_adr_i;
                d_branching <= branching;
            end if;
        end if;
    end process;
    if_rst_o <= '0';
    id_rst_o <= branching or d_branching;
    ex_rst_o <= '0';

    branching_o <= branching or d_branching;

    if_en_o <= '1';
    id_en_o <= '1';
    ex_en_o <= 
        '0' when (ex_load_pc_i or csr_load_pc_i or branching) = '1' else
        --'0' when reg_mutex(to_integer(unsigned(ex_rd_adr_i))) = '1' and ex_rd_we_i = '1' and op_use_rs1 = '1' else
        --'0' when reg_mutex(to_integer(unsigned(ex_rd_adr_i))) = '1' and ex_rd_we_i = '1' and op_use_rs2 = '1' else
        --'0' when reg_mutex(to_integer(unsigned(ex_mem_rd_adr_i))) = '1' and ex_mem_rd_we_i = '1' and op_use_rs1 = '1' else
        --'0' when reg_mutex(to_integer(unsigned(ex_mem_rd_adr_i))) = '1' and ex_mem_rd_we_i = '1' and op_use_rs2 = '1' else
        '0' when ex_rd_adr_i = rs1_adr and ex_rd_we_i = '1' and op_use_rs1 = '1' else
        '0' when ex_rd_adr_i = rs2_adr and ex_rd_we_i = '1' and op_use_rs2 = '1' else
        '0' when ex_mem_rd_adr_i = rs1_adr and ex_mem_rd_we_i = '1' and op_use_rs1 = '1' else
        '0' when ex_mem_rd_adr_i = rs2_adr and ex_mem_rd_we_i = '1' and op_use_rs2 = '1' else
        '0' when reg_mutex(to_integer(unsigned(rs1_adr))) = '1' and (op_use_rs1 = '1' or op_csr = '1') else
        '0' when reg_mutex(to_integer(unsigned(rs2_adr))) = '1' and op_use_rs2 = '1' else
        '0' when ex_rd_adr_i = rs1_adr and ex_rd_we_i = '1' and op_csr = '1' else
        '1';

    with opcode_i select
        op_use_rs1 <= 
            '1' when RV32I_OP_JALR,
            '1' when RV32I_OP_BRANCH,
            '1' when RV32I_OP_REG_IMM,
            '1' when RV32I_OP_REG_REG,
            '1' when RV32I_OP_LOAD,
            '1' when RV32I_OP_STORE,
            '0' when others;
    with opcode_i select
        op_use_rs2 <= 
            '1' when RV32I_OP_BRANCH,
            '1' when RV32I_OP_REG_REG,
            '1' when RV32I_OP_STORE,
            '0' when others;
    op_csr <= 
        '1' when opcode_i = RV32I_OP_SYS and funct3_i(2) = '0' else
        '0'; 
    
-- rs1 :
-- RV32I_OP_JALR | RV32I_OP_BRANCH | RV32I_OP_REG_IMM | RV32I_OP_REG_REG | RV32I_OP_LOAD | RV32I_OP_STORE
-- rs2 : 
-- RV32I_OP_BRANCH | RV32I_OP_REG_REG | RV32I_OP_STORE
    
end architecture rtl;