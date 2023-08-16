library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity memory is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        opcode_i : in opcode_t;
        funct3_i : in std_logic_vector(2 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        alu_result_a_i : in std_logic_vector(31 downto 0);
        alu_result_b_i : in std_logic_vector(31 downto 0);
        shifter_result_i : in std_logic_vector(31 downto 0);
        csr_read_data_i : in std_logic_vector(31 downto 0);
        valid_o : out std_logic;
        opcode_o : out opcode_t;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        rd_dat_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        alu_result_a_o : out std_logic_vector(31 downto 0);
        alu_result_b_o : out std_logic_vector(31 downto 0);
        cmd_en_i : in std_logic;
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_dat_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic;
        cmd_we_o : out std_logic;
        cmd_siz_o : out std_logic_vector(1 downto 0);
        cmd_rdy_i : in std_logic;
        ready_o : out std_logic
    );
end entity memory;

architecture rtl of memory is
    signal valid, cmd_valid : std_logic;
    signal opcode : opcode_t;
    signal funct3 : std_logic_vector(2 downto 0);
    signal alu_result_a, alu_result_b : std_logic_vector(31 downto 0);
begin

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    valid <= '0';
                else
                    valid <= valid_i;
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                rd_adr_o <= rd_adr_i;
                rd_we_o <= rd_we_i;
                opcode <= opcode_i;
                funct3 <= funct3_i;
                alu_result_a <= alu_result_a_i;
                alu_result_b <= alu_result_b_i;
            end if;
        end if;
    end process;

    opcode_o <= opcode;
    funct3_o <= funct3;
    rd_dat_o <=
        csr_read_data_i when (opcode.sys) = '1' else
        shifter_result_i when (opcode.reg_reg or opcode.reg_imm) = '1' and funct3(1 downto 0) = "01" else 
        alu_result_a;
    valid_o <= valid;

    cmd_adr_o <= alu_result_a;
    cmd_dat_o <= 
        alu_result_b(7 downto 0) & alu_result_b(7 downto 0) & alu_result_b(7 downto 0) & alu_result_b(7 downto 0) when funct3(1 downto 0) = "00" else
        alu_result_b(15 downto 0) & alu_result_b(15 downto 0) when funct3(1 downto 0) = "01" else
        alu_result_b;
    cmd_valid <= (opcode.store or opcode.load) and valid;
    cmd_vld_o <= cmd_valid and cmd_en_i;
    cmd_we_o <= opcode.store;
    cmd_siz_o <= funct3(1 downto 0);

    process (opcode, valid, cmd_rdy_i)
    begin
        if ((opcode.store or opcode.load) and valid) = '1' then
            ready_o <= cmd_rdy_i;
        else
            ready_o <= '1';
        end if;
    end process;

    alu_result_a_o <= alu_result_a;
    alu_result_b_o <= alu_result_b;

end architecture rtl;