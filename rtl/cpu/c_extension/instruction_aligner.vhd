library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity instruction_aligner is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        enable_i : in std_logic;
        load_pc_i : in std_logic;
        target_pc_i : in std_logic_vector(31 downto 0);
        instr_vld_i : in std_logic;
        instr_dat_i : in std_logic_vector(31 downto 0);
        instr_vld_o : out std_logic;
        instr_dat_o : out std_logic_vector(31 downto 0);
        instr_rvc_o : out std_logic;
        stall_o : out std_logic
    );
end entity instruction_aligner;

architecture rtl of instruction_aligner is
    signal pc_q : std_logic;
    signal instr_dat_q : std_logic_vector(15 downto 0);
    signal compress_instr_low, compress_instr_high : std_logic;
    signal dispatch_compress_high_q : std_logic;
    signal aligned_q : std_logic;
    signal stall, stall_q : std_logic;
begin

    compress_instr_high <= '1' when instr_dat_i(17 downto 16) /= "11" else '0';
    compress_instr_low  <= '1' when instr_dat_i(01 downto 00) /= "11" else '0';

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                if load_pc_i = '1' then
                    pc_q <= target_pc_i(1);
                elsif pc_q = '0' and instr_vld_i = '1' and compress_instr_low = '1' then
                    pc_q <= '1';
                elsif pc_q = '1' and ((instr_vld_i = '1' and compress_instr_high = '1' and aligned_q = '0') or dispatch_compress_high_q = '1') then
                    pc_q <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                dispatch_compress_high_q <= aligned_q and compress_instr_high and instr_vld_i and not load_pc_i;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if instr_vld_i = '1' then
                instr_dat_q <= instr_dat_i(31 downto 16);                
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if load_pc_i = '1' or instr_vld_i = '1' then
                aligned_q <= not (load_pc_i and target_pc_i(1));
            end if;
        end if;
    end process;

    stall <=
        '1' when pc_q = '0' and instr_vld_i = '1' and compress_instr_low = '1'       and compress_instr_high = '1' and aligned_q = '1' else
        '1' when pc_q = '1' and instr_vld_i = '1' and                                    compress_instr_high = '1' and aligned_q = '1' else
        '0';

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                stall_q <= stall;
            end if;
        end if;
    end process;

    stall_o <= (enable_i and stall) or (not enable_i and stall_q);

    instr_dat_o <=
        instr_dat_i(15 downto 0) & instr_dat_q               when pc_q = '1' and aligned_q = '1' else
        (31 downto 16 => '-')    & instr_dat_i(31 downto 16) when pc_q = '1' and aligned_q = '0' else
        instr_dat_i                                          when pc_q = '0' and aligned_q = '1' else
        (others => '-');

    instr_vld_o <=
        '1' when pc_q = '0' and instr_vld_i = '1'              and aligned_q = '1' else
        '1' when pc_q = '1' and instr_vld_i = '1'              and aligned_q = '1' else
        '1' when pc_q = '1' and instr_vld_i = '1'              and aligned_q = '0' and compress_instr_high = '1' else
        '1' when pc_q = '1' and dispatch_compress_high_q = '1' and aligned_q = '1' else
        '0';

    instr_rvc_o <=
        '1' when pc_q = '0'      and compress_instr_low = '1'       else
        '1' when pc_q = '1'      and dispatch_compress_high_q = '1' else
        '1' when aligned_q = '0' and compress_instr_high = '1'      else
        '0';

-- /*
--     - ALIGNED
--         - iv && cl &&  ch -> DISPATCH HIGH
--         - iv && cl && !ch -> UNALIGNED
--     - UNALIGNED
--         - iv && ch        -> DISPATCH HIGH
--  */
end architecture rtl;