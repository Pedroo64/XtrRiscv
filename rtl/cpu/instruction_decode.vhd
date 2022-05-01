library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity instruction_decode is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        vld_i : in std_logic;
        instr_dat_i : in std_logic_vector(31 downto 0);
        opcode_o : out std_logic_vector(6 downto 0);
        pc_i : in std_logic_vector(31 downto 0);
        rs1_adr_o : out std_logic_vector(4 downto 0);
        rs2_adr_o : out std_logic_vector(4 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        immediate_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        rdy_o : out std_logic;
        vld_o : out std_logic;
        rdy_i : in std_logic;
        rs1_adr_latch_o : out std_logic_vector(4 downto 0);
        rs2_adr_latch_o : out std_logic_vector(4 downto 0)
    );
end entity instruction_decode;

architecture rtl of instruction_decode is
    signal vld, ready : std_logic;
    signal rs1_adr_latch, rs2_adr_latch : std_logic_vector(4 downto 0);
begin
    rs1_adr_o <= 
        instr_dat_i(19 downto 15) when ready = '1' else 
        rs1_adr_latch;
    rs2_adr_o <= 
        instr_dat_i(24 downto 20) when ready = '1' else 
        rs2_adr_latch;
        
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            vld <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                vld <= '0';
            else
                if en_i = '1' and vld_i = '1' and rdy_i = '1' then
                    rs1_adr_latch <= instr_dat_i(19 downto 15);
                    rs2_adr_latch <= instr_dat_i(24 downto 20);
                    opcode_o <= instr_dat_i(6 downto 0);
                    pc_o <= pc_i;
                    funct3_o <= instr_dat_i(14 downto 12);
                    funct7_o <= instr_dat_i(31 downto 25);
                    rd_adr_o <= instr_dat_i(11 downto 7);
                    rd_we_o <= '0';
                    case instr_dat_i(6 downto 0) is
                        when RV32I_OP_REG_REG => -- R Type
                            vld <= '1';
                            rd_we_o <= '1';

                        when RV32I_OP_LOAD | RV32I_OP_REG_IMM | RV32I_OP_SYS | RV32I_OP_JALR => -- I Type
                            immediate_o(31 downto 11) <= (others => instr_dat_i(31));
                            immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                            immediate_o(4 downto 1) <= instr_dat_i(24 downto 21);
                            immediate_o(0) <= instr_dat_i(20);
                            vld <= '1';
                            rd_we_o <= '1';

                        when RV32I_OP_STORE => -- S Type
                            immediate_o(31 downto 11) <= (others => instr_dat_i(31));
                            immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                            immediate_o(4 downto 1) <= instr_dat_i(11 downto 8);
                            immediate_o(0) <= instr_dat_i(7);
                            vld <= '1';

                        when RV32I_OP_BRANCH => -- B Type
                            immediate_o(31 downto 12) <= (others => instr_dat_i(31));
                            immediate_o(11) <= instr_dat_i(7);
                            immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                            immediate_o(4 downto 1) <= instr_dat_i(11 downto 8);
                            immediate_o(0) <= '0';
                            vld <= '1';

                        when RV32I_OP_LUI | RV32I_OP_AUIPC => -- U Type
                            immediate_o(31 downto 12) <= instr_dat_i(31 downto 12);
                            immediate_o(11 downto 0) <= (others => '0');
                            vld <= '1';
                            rd_we_o <= '1';

                        when RV32I_OP_JAL => -- J Type
                            immediate_o(31 downto 20) <= (others => instr_dat_i(31));
                            immediate_o(19 downto 12) <= instr_dat_i(19 downto 12);
                            immediate_o(11) <= instr_dat_i(20);
                            immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                            immediate_o(4 downto 1) <= instr_dat_i(24 downto 21);
                            immediate_o(0) <= '0';
                            vld <= '1';
                            rd_we_o <= '1';

                        when others =>
                    end case;
                elsif vld = '1' and rdy_i = '1' then
                    vld <= '0';
                end if;
            end if;        
        end if;
    end process;
    
    ready <= 
        '0' when vld = '1' and rdy_i = '0' else
--        '0' when vld_i = '1' and rdy_i = '0' else
        en_i;

    rdy_o <= ready;

    vld_o <= vld;

    rs1_adr_latch_o <= rs1_adr_latch;
    rs2_adr_latch_o <= rs2_adr_latch;

end architecture rtl;