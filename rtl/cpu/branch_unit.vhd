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
        execute_opcode_i : in opcode_t;
        execute_rs1_dat_i : in std_logic_vector(31 downto 0);
        execute_rs2_dat_i : in std_logic_vector(31 downto 0);
        execute_funct3_i : in std_logic_vector(2 downto 0);
        memory_valid_i : in std_logic;
        memory_enable_i : in std_logic;
        memory_opcode_i : in opcode_t;
        memory_funct3_i : in std_logic_vector(2 downto 0);
        memory_target_pc_i : in std_logic_vector(31 downto 0);
        exception_target_pc_i : in std_logic_vector(31 downto 0);
        exception_load_pc_i : in std_logic;
        target_pc_o : out std_logic_vector(31 downto 0);
        branch_o : out std_logic;
        load_pc_o : out std_logic
    );
end entity branch_unit;

architecture rtl of branch_unit is
    signal opcode : opcode_t;
    signal funct3 : std_logic_vector(2 downto 0);
    signal enable, valid, cmp_lt, cmp_eq : std_logic;
    signal execute_cmp_signed, execute_cmp_lt, execute_cmp_eq : std_logic;
    signal memory_cmp_lt, memory_cmp_eq : std_logic;
    signal nxt_branch, branch : std_logic;
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
--    execute_cmp_lt <= alu_lt_i;
--    execute_cmp_eq <= alu_eq_i;
    execute_cmp_signed <= not execute_funct3_i(1);

    process (execute_opcode_i, execute_funct3_i, execute_cmp_lt, execute_cmp_eq)
    begin
        nxt_branch <= '0';
        if execute_opcode_i.jal = '1' then
            nxt_branch <= '1';
        else
            if execute_opcode_i.branch = '1' then
                if execute_funct3_i(2) = '1' then
                    if (execute_cmp_lt xor execute_funct3_i(0)) = '1' then
                        nxt_branch <= '1';
                    end if;
                else
                    if (execute_cmp_eq xor execute_funct3_i(0)) = '1' then
                        nxt_branch <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_enable_i = '1' then
                memory_cmp_lt <= execute_cmp_lt;
                memory_cmp_eq <= execute_cmp_eq;
                branch <= nxt_branch;
            end if;
        end if;
    end process;

    valid <= memory_valid_i;

    load_pc_o <= (branch and valid) or exception_load_pc_i or not booted_i;
    target_pc_o <=
        G_BOOT_ADDRESS when booted_i = '0' else
        exception_target_pc_i(31 downto 2) & "00" when exception_load_pc_i = '1' else
        memory_target_pc_i when branch = '1' else
        (others => '-');
    branch_o <= branch and valid;
end architecture rtl;