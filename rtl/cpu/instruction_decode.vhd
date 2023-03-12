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
    signal comb_rs1_adr, comb_rs2_adr : std_logic_vector(4 downto 0);
    signal rs1_adr, rs2_adr : std_logic_vector(4 downto 0);
    signal opcode : std_logic_vector(6 downto 0);
    signal s_opcode : opcode_t;
begin
    opcode <= instr_dat_i(6 downto 0);

    process (opcode)
    begin
        s_opcode.lui <= '0';
        s_opcode.auipc <= '0';
        s_opcode.jal <= '0';
        s_opcode.jalr <= '0';
        s_opcode.branch <= '0';
        s_opcode.load <= '0';
        s_opcode.store <= '0';
        s_opcode.reg_imm <= '0';
        s_opcode.reg_reg <= '0';
        s_opcode.fence <= '0';
        s_opcode.sys <= '0';
        s_opcode.illegal <= '0';
        case opcode is
            when RV32I_OP_LUI =>
                s_opcode.lui <= '1';
            when RV32I_OP_AUIPC =>
                s_opcode.auipc <= '1';    
            when RV32I_OP_JAL =>
                s_opcode.jal <= '1';
            when RV32I_OP_JALR =>
                s_opcode.jalr <= '1';
            when RV32I_OP_BRANCH =>
                s_opcode.branch <= '1';
            when RV32I_OP_LOAD =>
                s_opcode.load <= '1';
            when RV32I_OP_STORE =>
                s_opcode.store <= '1';
            when RV32I_OP_REG_IMM =>
                s_opcode.reg_imm <= '1';
            when RV32I_OP_REG_REG =>
                s_opcode.reg_reg <= '1';
            when RV32I_OP_FENCE =>
                s_opcode.fence <= '1';
            when RV32I_OP_SYS =>
                s_opcode.sys <= '1';
            when others =>
                s_opcode.illegal <= '1';
        end case;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if vld_i = '1' and ready = '1' then
                rs1_adr <= comb_rs1_adr;
                rs2_adr <= comb_rs2_adr;
                pc_o <= pc_i;
                funct3_o <= instr_dat_i(14 downto 12);
                funct7_o <= instr_dat_i(31 downto 25);
                rd_adr_o <= instr_dat_i(11 downto 7);
                opcode_o <= s_opcode;
                if (s_opcode.reg_reg or s_opcode.load or s_opcode.reg_imm or s_opcode.sys or s_opcode.jalr or s_opcode.lui or s_opcode.auipc or s_opcode.jal) = '1' then
                    rd_we_o <= '1';
                else
                    rd_we_o <= '0';
                end if;
                if (s_opcode.load or s_opcode.reg_imm or s_opcode.sys or s_opcode.jalr) = '1' then
                    immediate_o(31 downto 11) <= (others => instr_dat_i(31));
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(24 downto 21);
                    immediate_o(0) <= instr_dat_i(20);
                elsif (s_opcode.store) = '1' then
                    immediate_o(31 downto 11) <= (others => instr_dat_i(31));
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(11 downto 8);
                    immediate_o(0) <= instr_dat_i(7);
                elsif (s_opcode.branch) = '1' then
                    immediate_o(31 downto 12) <= (others => instr_dat_i(31));
                    immediate_o(11) <= instr_dat_i(7);
                    immediate_o(10 downto 5) <= instr_dat_i(30 downto 25);
                    immediate_o(4 downto 1) <= instr_dat_i(11 downto 8);
                    immediate_o(0) <= '0';
                elsif (s_opcode.lui or s_opcode.auipc) = '1' then
                    immediate_o(31 downto 12) <= instr_dat_i(31 downto 12);
                    immediate_o(11 downto 0) <= (others => '0');
                elsif (s_opcode.jal) = '1' then
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

    comb_rs1_adr <= 
        (others => '0') when s_opcode.lui = '1' and ready = '1' else
        instr_dat_i(19 downto 15) when ready = '1' else
        rs1_adr;

    comb_rs2_adr <=
        instr_dat_i(24 downto 20) when ready = '1' else
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
                    case opcode is
                        when RV32I_OP_LUI | RV32I_OP_AUIPC | RV32I_OP_JAL | RV32I_OP_JALR | RV32I_OP_BRANCH | RV32I_OP_LOAD | RV32I_OP_STORE | RV32I_OP_REG_IMM | RV32I_OP_REG_REG | RV32I_OP_FENCE | RV32I_OP_SYS =>
                            vld <= '1';
                        when others =>
                            vld <= '0';
                    end case;
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