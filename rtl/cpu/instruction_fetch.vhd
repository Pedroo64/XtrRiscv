library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.vhdl_utils.all;

entity instruction_fetch is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_EXTENSION_C : boolean := FALSE
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
        instr_valid_o : out std_logic;
        instr_data_o : out std_logic_vector(31 downto 0);
        instr_compressed_o : out std_logic;
        booted_o : out std_logic;
        prefetch_full_o : out std_logic
    );
end entity instruction_fetch;

architecture rtl of instruction_fetch is
    signal enable : std_logic;
    signal booted, cmd_valid : std_logic;
    signal pc, next_pc : std_logic_vector(31 downto 0);
    signal instr_data, instr_data_q : std_logic_vector(31 downto 0);
    signal instr_valid : std_logic;
    signal stall, d_cmd_vld : std_logic;
begin
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            booted <= '0';
        elsif rising_edge(clk_i) then
            booted <= not srst_i;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable = '1' and cmd_rdy_i = '1' then
                pc <= next_pc;
            end if;
        end if;
    end process;
    next_pc <=
        target_pc_i when load_pc_i = '1' else
        std_logic_vector(unsigned(pc) + 4);

    cmd_valid <= booted and enable;

    cmd_adr_o <= pc;
    cmd_vld_o <= cmd_valid;
    booted_o <= booted;

    enable <= (enable_i and not stall) or load_pc_i;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                d_cmd_vld <= cmd_valid and cmd_rdy_i and not load_pc_i;
            end if;
        end if;
    end process;

    instr_data <= rsp_dat_i when rsp_vld_i = '1' else instr_data_q;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            instr_data_q <= instr_data;
        end if;
    end process;


    gen_aligner: if G_EXTENSION_C = TRUE generate
        signal pc_align, aligned : std_logic;
        signal d_instr_data_high : std_logic_vector(15 downto 0);
        signal compress_instr_low, compress_instr_high : std_logic;
        signal dispatch_high_compress : std_logic;
    begin
        compress_instr_high <= '1' when instr_data(17 downto 16) /= "11" else '0';
        compress_instr_low  <= '1' when instr_data(01 downto 00) /= "11" else '0';

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if enable_i = '1' then
                    if load_pc_i = '1' then
                        pc_align <= target_pc_i(1);
                    else
                        if pc_align = '0' then
                            if d_cmd_vld = '1' and compress_instr_low = '1' then
                                pc_align <= '1';
                            end if;
                        else
                            if dispatch_high_compress = '1' or (d_cmd_vld = '1' and aligned = '0' and compress_instr_high = '1') then
                                pc_align <= '0';
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if enable_i = '1' then
                    d_instr_data_high <= instr_data(31 downto 16);
                    dispatch_high_compress <= d_cmd_vld and compress_instr_high and not load_pc_i;
                    if load_pc_i = '1' then
                        aligned <= not target_pc_i(1);
                    elsif d_cmd_vld = '1' then
                        aligned <= '1';
                    end if;
                end if;
            end if;
        end process;

        stall <=
            '1' when pc_align = '0' and d_cmd_vld = '1' and compress_instr_low = '1' and compress_instr_high = '1' else
            '1' when pc_align = '1' and d_cmd_vld = '1' and compress_instr_high = '1' and aligned = '1' else
            '0';

        instr_valid <=
            '1' when pc_align = '0' and d_cmd_vld = '1' and aligned = '1' else
            '1' when pc_align = '1' and dispatch_high_compress = '1' and aligned = '1' else
            '1' when pc_align = '1' and d_cmd_vld = '1' and aligned = '1' else
            '1' when pc_align = '1' and d_cmd_vld = '1' and aligned = '0' and compress_instr_high = '1' else
            '0';

        instr_data_o <=
            instr_data(15 downto 0) & d_instr_data_high when pc_align = '1' and aligned = '1' else
            (31 downto 16 => 'X') & instr_data(31 downto 16) when pc_align = '1' and aligned = '0' else
            instr_data;

        instr_compressed_o <= (not pc_align and compress_instr_low) or (pc_align and dispatch_high_compress) or (not aligned and compress_instr_high);
        
    end generate gen_aligner;

    gen_no_aligner: if G_EXTENSION_C = FALSE generate
        stall <= '0';
        instr_valid <= d_cmd_vld;
        instr_data_o <= instr_data;
        instr_compressed_o <= '0';
    end generate gen_no_aligner;
        
    instr_valid_o <= instr_valid;

end architecture rtl;
