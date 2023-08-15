library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity instruction_fecth is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0')
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        load_pc_i : in std_logic;
        target_pc_i : in std_logic_vector(31 downto 0);
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic;
        cmd_rdy_i : in std_logic;
        rsp_dat_i : in std_logic_vector(31 downto 0);
        rsp_vld_i : in std_logic;
        valid_o : out std_logic;
        instr_o : out std_logic_vector(31 downto 0);
        booted_o : out std_logic
    );
end entity instruction_fecth;

architecture rtl of instruction_fecth is
    signal booted, valid : std_logic;
    signal pc, next_pc : std_logic_vector(31 downto 0);
begin
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            booted <= '0';
        elsif rising_edge(clk_i) then
            booted <= not srst_i;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    valid <= '0';
                else
                    valid <= booted and cmd_rdy_i;
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' and cmd_rdy_i = '1' then
                pc <= next_pc;
            end if;
        end if;
    end process;
    next_pc <= 
        target_pc_i when load_pc_i = '1' else
        std_logic_vector(unsigned(pc) + 4);

    cmd_adr_o <= pc;
    cmd_vld_o <= booted and enable_i;
    valid_o <= valid;
    instr_o <= rsp_dat_i;
    booted_o <= booted;

end architecture rtl;