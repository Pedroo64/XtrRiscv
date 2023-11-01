library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity instruction_decode is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        instr_i : in std_logic_vector(31 downto 0);
        compressed_i : in std_logic;
        valid_o : out std_logic;
        opcode_o : out opcode_t;
        opcode_type_o : out opcode_type_t;
        rs1_adr_o : out std_logic_vector(4 downto 0);
        rs2_adr_o : out std_logic_vector(4 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        immediate_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        compressed_o : out std_logic;
        instr_o : out std_logic_vector(31 downto 0)
    );
end entity instruction_decode;

architecture rtl of instruction_decode is
    signal fetched_instr, decompressed_instr, instr_dat : std_logic_vector(31 downto 0);
    signal instr_opcode : std_logic_vector(6 downto 0);
    signal compressed : std_logic;
    signal opcode : opcode_t;
    signal opcode_type : opcode_type_t;
begin
    -- decompressor
    u_decompressor : entity work.decompressor
        port map (
            instr_i => instr_i(15 downto 0),
            instr_o => decompressed_instr
        );
    fetched_instr <= decompressed_instr when compressed_i = '1' else instr_i;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                instr_dat <= fetched_instr;
                compressed <= compressed_i;
            end if;
        end if;
    end process;

    instr_opcode <= instr_dat(6 downto 2) & "11";

    opcode.illegal <= '0';
-- opcode decode
    process (instr_opcode)
    begin
        opcode.lui <= '0';
        opcode.auipc <= '0';
        opcode.jal <= '0';
        opcode.jalr <= '0';
        opcode.branch <= '0';
        opcode.load <= '0';
        opcode.store <= '0';
        opcode.reg_imm <= '0';
        opcode.reg_reg <= '0';
        opcode.fence <= '0';
        opcode.sys <= '0';
        case instr_opcode is
            when RV32I_OP_LUI => opcode.lui <= '1';
            when RV32I_OP_AUIPC => opcode.auipc <= '1';
            when RV32I_OP_JAL => opcode.jal <= '1';
            when RV32I_OP_JALR => opcode.jalr <= '1';
            when RV32I_OP_BRANCH => opcode.branch <= '1';
            when RV32I_OP_LOAD => opcode.load <= '1';
            when RV32I_OP_STORE => opcode.store <= '1';
            when RV32I_OP_REG_IMM => opcode.reg_imm <= '1';
            when RV32I_OP_REG_REG => opcode.reg_reg <= '1';
            when RV32I_OP_FENCE => opcode.fence <= '1';
            when RV32I_OP_SYS => opcode.sys <= '1';
            when others => 
        end case;
    end process;

-- opcode type decode
    process (instr_opcode)
    begin
        opcode_type.r_type <= '0';
        opcode_type.i_type <= '0';
        opcode_type.s_type <= '0';
        opcode_type.b_type <= '0';
        opcode_type.u_type <= '0';
        opcode_type.j_type <= '0';
        case instr_opcode is
            when RV32I_OP_REG_REG => opcode_type.r_type <= '1';
            when RV32I_OP_JALR | RV32I_OP_LOAD | RV32I_OP_REG_IMM | RV32I_OP_SYS => opcode_type.i_type <= '1';
            when RV32I_OP_STORE => opcode_type.s_type <= '1';
            when RV32I_OP_BRANCH => opcode_type.b_type <= '1';
            when RV32I_OP_LUI | RV32I_OP_AUIPC => opcode_type.u_type <= '1';
            when RV32I_OP_JAL => opcode_type.j_type <= '1';
            when others =>
        end case;
    end process;

    opcode_o <= opcode;

    rs1_adr_o <= (others => '0') when opcode.lui = '1' else instr_dat(19 downto 15);
    rs2_adr_o <= instr_dat(24 downto 20);
    rd_adr_o <= instr_dat(11 downto 7);
    
    funct3_o <= instr_dat(14 downto 12);
    funct7_o <= instr_dat(31 downto 25);
    rd_we_o <= opcode_type.r_type or opcode_type.i_type or opcode_type.u_type or opcode_type.j_type;
    opcode_type_o <= opcode_type;
    compressed_o <= compressed;
    
    process (instr_opcode, instr_dat)
    begin
        case instr_opcode is
            when RV32I_OP_LUI | RV32I_OP_AUIPC => 
                immediate_o <= instr_dat(31 downto 12) & (0 to 11 => '0');
            when RV32I_OP_JAL => 
                immediate_o <= (20 to 31 => instr_dat(31)) & instr_dat(19 downto 12) & instr_dat(20) & instr_dat(30 downto 25) & instr_dat(24 downto 21) & '0';
            when RV32I_OP_JALR | RV32I_OP_LOAD | RV32I_OP_REG_IMM | RV32I_OP_SYS => 
                immediate_o <= (11 to 31 => instr_dat(31)) & instr_dat(30 downto 25) & instr_dat(24 downto 21) & instr_dat(20);
            when RV32I_OP_BRANCH => 
                immediate_o <= (12 to 31 => instr_dat(31)) & instr_dat(7) & instr_dat(30 downto 25) & instr_dat(11 downto 8) & '0';
            when RV32I_OP_STORE =>
                immediate_o <= (11 to 31 => instr_dat(31)) & instr_dat(30 downto 25) & instr_dat(11 downto 8) & instr_dat(7);
            when others => 
                immediate_o <= (others => '-');
        end case;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid_o <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    valid_o <= '0';
                else
                    valid_o <= valid_i;
                end if;
            end if;
        end if;
    end process;

    -- DEBUG
    instr_o <= instr_dat;
end architecture rtl;