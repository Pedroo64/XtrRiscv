library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity branch_unit is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0')
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        booted_i : in std_logic;
        execute_rs1_dat_i : in std_logic_vector(31 downto 0);
        execute_rs2_dat_i : in std_logic_vector(31 downto 0);
        execute_funct3_i : in std_logic_vector(2 downto 0);
        memory_valid_i : in std_logic;
        memory_enable_i : in std_logic;
        memory_opcode_i : in opcode_t;
        memory_funct3_i : in std_logic_vector(2 downto 0);
        memory_target_pc_i : in std_logic_vector(31 downto 0);
        target_pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic
    );
end entity branch_unit;

architecture rtl of branch_unit is
    signal opcode : opcode_t;
    signal funct3 : std_logic_vector(2 downto 0);
    signal enable, valid, cmp_lt, cmp_eq, branch : std_logic;
    signal execute_cmp_signed, execute_cmp_lt, execute_cmp_eq : std_logic;
    signal memory_cmp_lt, memory_cmp_eq : std_logic;
begin
    
-- COMPARATOR
    u_comparator : entity work.comparator
        port map (
            a_i => execute_rs1_dat_i,
            b_i => execute_rs2_dat_i,
            signed_i => execute_cmp_signed,
            lt_o => execute_cmp_lt,
            eq_o => execute_cmp_eq
        );
    execute_cmp_signed <= not execute_funct3_i(1);
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_enable_i = '1' then
                memory_cmp_lt <= execute_cmp_lt;
                memory_cmp_eq <= execute_cmp_eq;
            end if;
        end if;
    end process;

    opcode <= memory_opcode_i;
    funct3 <= memory_funct3_i;
    enable <= memory_enable_i;
    valid <= memory_valid_i;
    cmp_lt <= memory_cmp_lt;
    cmp_eq <= memory_cmp_eq;

    process (opcode, cmp_eq, cmp_lt, funct3)
    begin
        if (opcode.jal or opcode.jalr) = '1' then
            branch <= '1';
        elsif opcode.branch = '1' then
            case funct3 is
                when RV32I_FN3_BEQ => branch <= cmp_eq;
                when RV32I_FN3_BNE => branch <= not cmp_eq;
                when RV32I_FN3_BLT | RV32I_FN3_BLTU => branch <= cmp_lt;
                when RV32I_FN3_BGE | RV32I_FN3_BGEU => branch <= not cmp_lt;            
                when others => branch <= '0';
            end case;
        else
            branch <= '0';
        end if;
    end process;

    load_pc_o <= (branch and enable and valid) or not booted_i;
    target_pc_o <=
        G_BOOT_ADDRESS when booted_i = '0' else
        memory_target_pc_i;

end architecture rtl;