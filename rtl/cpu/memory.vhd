library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity memory is
    generic (
        G_FULL_BARREL_SHIFTER : boolean := FALSE;
        G_SHIFTER_EARLY_INJECTION : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        opcode_i : in opcode_t;
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        alu_result_a_i : in std_logic_vector(31 downto 0);
        alu_result_b_i : in std_logic_vector(31 downto 0);
        shifter_result_i : in std_logic_vector(31 downto 0);
        shifter_ready_i : in std_logic;
        csr_read_data_i : in std_logic_vector(31 downto 0);
        valid_o : out std_logic;
        opcode_o : out opcode_t;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        rd_dat_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
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
    signal valid, cmd_valid, rd_we : std_logic;
    signal opcode : opcode_t;
    signal funct3 : std_logic_vector(2 downto 0);
    signal funct7 : std_logic_vector(6 downto 0);
    signal alu_result_a, alu_result_b, rd_dat : std_logic_vector(31 downto 0);
    signal busy : std_logic;
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
                rd_we <= rd_we_i;
                opcode <= opcode_i;
                funct3 <= funct3_i;
                funct7 <= funct7_i;
                alu_result_a <= alu_result_a_i;
                alu_result_b <= alu_result_b_i;
            end if;
        end if;
    end process;

    opcode_o <= opcode;
    funct3_o <= funct3;
    funct7_o <= funct7;
    process (opcode, funct3, csr_read_data_i, shifter_result_i, alu_result_a)
    begin
        if opcode.sys = '1' then
            rd_dat <= csr_read_data_i;
        elsif G_SHIFTER_EARLY_INJECTION = FALSE and (opcode.reg_reg or opcode.reg_imm) = '1' and funct3(1 downto 0) = "01" then
            rd_dat <= shifter_result_i;
        else
            rd_dat <= alu_result_a;
        end if;
    end process;
    rd_dat_o <= rd_dat;
    valid_o <= valid;
    rd_we_o <= rd_we and valid;

--    cmd_adr_o <= alu_result_a;
--    cmd_dat_o <= 
--        alu_result_b(7 downto 0) & alu_result_b(7 downto 0) & alu_result_b(7 downto 0) & alu_result_b(7 downto 0) when funct3(1 downto 0) = "00" else
--        alu_result_b(15 downto 0) & alu_result_b(15 downto 0) when funct3(1 downto 0) = "01" else
--        alu_result_b;
--    cmd_valid <= (opcode.store or opcode.load) and valid;
--    cmd_vld_o <= cmd_valid and cmd_en_i;
--    cmd_we_o <= opcode.store;
--    cmd_siz_o <= funct3(1 downto 0);

--    process (opcode, cmd_rdy_i, funct3, shifter_ready_i)
--    begin
--        if (opcode.store or opcode.load) = '1' then
--            busy <= not cmd_rdy_i;
--        elsif (G_FULL_BARREL_SHIFTER = FALSE and G_SHIFTER_EARLY_INJECTION = FALSE and (opcode.reg_reg or opcode.reg_imm) = '1' and funct3(1 downto 0) = "01") then
--            busy <= not shifter_ready_i;
--        else
--            busy <= '0';
--        end if;
--    end process;

    busy <= 
        '1' when (opcode.reg_reg or opcode.reg_imm) = '1' and funct3(1 downto 0) = "01" and G_FULL_BARREL_SHIFTER = FALSE and G_SHIFTER_EARLY_INJECTION = FALSE else
        '0';

    ready_o <= not (busy and valid);

    alu_result_a_o <= alu_result_a;
    alu_result_b_o <= alu_result_b;

end architecture rtl;