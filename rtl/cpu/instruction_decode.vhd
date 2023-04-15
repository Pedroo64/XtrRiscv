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
        opcode_o : out opcode_t;
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
    signal next_rs1, next_rs2 : std_logic_vector(4 downto 0);
    signal comb_rs1_adr, comb_rs2_adr : std_logic_vector(4 downto 0);
    signal rs1_adr, rs2_adr : std_logic_vector(4 downto 0);
    signal opcode : opcode_t;
begin
    opcode.lui <=     '1' when instr_dat_i(6 downto 0) = RV32I_OP_LUI else '0';
    opcode.auipc <=   '1' when instr_dat_i(6 downto 0) = RV32I_OP_AUIPC else '0';
    opcode.jal <=     '1' when instr_dat_i(6 downto 0) = RV32I_OP_JAL else '0';
    opcode.jalr <=    '1' when instr_dat_i(6 downto 0) = RV32I_OP_JALR else '0';
    opcode.branch <=  '1' when instr_dat_i(6 downto 0) = RV32I_OP_BRANCH else '0';
    opcode.load <=    '1' when instr_dat_i(6 downto 0) = RV32I_OP_LOAD else '0';
    opcode.store <=   '1' when instr_dat_i(6 downto 0) = RV32I_OP_STORE else '0';
    opcode.reg_imm <= '1' when instr_dat_i(6 downto 0) = RV32I_OP_REG_IMM else '0';
    opcode.reg_reg <= '1' when instr_dat_i(6 downto 0) = RV32I_OP_REG_REG else '0';
    opcode.fence <=   '1' when instr_dat_i(6 downto 0) = RV32I_OP_FENCE else '0';
    opcode.sys <=     '1' when instr_dat_i(6 downto 0) = RV32I_OP_SYS else '0';
    opcode.illegal <= '0';

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if vld_i = '1' and ready = '1' then
                rs1_adr <= next_rs1;
                rs2_adr <= next_rs2;
                pc_o <= pc_i;
                funct3_o <= instr_dat_i(14 downto 12);
                funct7_o <= instr_dat_i(31 downto 25);
                rd_adr_o <= instr_dat_i(11 downto 7);
                opcode_o <= opcode;
                if (opcode.reg_reg or opcode.load or opcode.reg_imm or opcode.sys or opcode.jalr or opcode.lui or opcode.auipc or opcode.jal) = '1' then
                    rd_we_o <= '1';
                else
                    rd_we_o <= '0';
                end if;
                if (opcode.load or opcode.reg_imm or opcode.sys or opcode.jalr) = '1' then
                    immediate_o(31 downto 11) <= (others => instr_dat_i(31));
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(24 downto 21);
                    immediate_o(0) <= instr_dat_i(20);
                elsif (opcode.store) = '1' then
                    immediate_o(31 downto 11) <= (others => instr_dat_i(31));
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(11 downto 8);
                    immediate_o(0) <= instr_dat_i(7);
                elsif (opcode.branch) = '1' then
                    immediate_o(31 downto 12) <= (others => instr_dat_i(31));
                    immediate_o(11) <= instr_dat_i(7);
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(11 downto 8);
                    immediate_o(0) <= '0';
                elsif (opcode.lui or opcode.auipc) = '1' then
                    immediate_o(31 downto 12) <= instr_dat_i(31 downto 12);
                    immediate_o(11 downto 0) <= (others => '0');
                elsif (opcode.jal) = '1' then
                    immediate_o(31 downto 20) <= (others => instr_dat_i(31));
                    immediate_o(19 downto 12) <= instr_dat_i(19 downto 12);
                    immediate_o(11) <= instr_dat_i(20);
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(24 downto 21);
                    immediate_o(0) <= '0';
                else
                    immediate_o <= (others => '-');
                end if;
            end if;
        end if;
    end process;

    next_rs1 <= (others => '0') when opcode.lui = '1' else instr_dat_i(19 downto 15);
    next_rs2 <= instr_dat_i(24 downto 20);

    comb_rs1_adr <= 
        next_rs1 when ready = '1' else
        rs1_adr;

    comb_rs2_adr <=
        next_rs2 when ready = '1' else
        rs2_adr;

    rs1_adr_o <= comb_rs1_adr;
    rs2_adr_o <= comb_rs2_adr;
        
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            vld <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                vld <= '0';
            else
                if vld_i = '1' and ready = '1' then
                    vld <= (opcode.lui or opcode.auipc or opcode.jal or opcode.jalr or opcode.branch or opcode.load or opcode.store or opcode.reg_imm or opcode.reg_reg or opcode.sys);
                elsif ready = '1' then
                    vld <= '0';
                end if;
            end if;        
        end if;
    end process;

    ready <= 
        '0' when vld = '1' and rdy_i = '0' else
        en_i;

    rdy_o <= ready;

    vld_o <= vld;

    rs1_adr_latch_o <= rs1_adr;
    rs2_adr_latch_o <= rs2_adr;

end architecture rtl;