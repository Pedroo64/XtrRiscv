library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity instruction_fetch is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_PREFETCH_SIZE : integer := 2;
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
    signal booted, valid, cmd_valid : std_logic;
    signal pc, next_pc : std_logic_vector(31 downto 0);
    signal prefetch_full : std_logic;
    signal rsp_valid : std_logic;
    signal prefetch_flush : std_logic;
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
            if enable = '1' then
                if flush_i = '1' then
                    valid <= '0';
                else
                    valid <= cmd_rdy_i;
                end if;
            end if;
        end if;
    end process;

    enable <= not prefetch_full or load_pc_i;

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
    
    rsp_valid <= valid and rsp_vld_i;

    -- prefetch
    prefetch_flush <= flush_i;
    u_prefetch : entity work.prefetch
        generic map (
            G_PREFETCH_DEPTH => G_PREFETCH_SIZE,
            G_EXTENSION_C => G_EXTENSION_C
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            enable_i => enable_i,
            flush_i => prefetch_flush,
            valid_i => cmd_valid,
            load_pc_i => load_pc_i,
            pc_align_i => target_pc_i(1),
            instr_valid_i => rsp_valid,
            instr_data_i => rsp_dat_i,
            valid_o => instr_valid_o,
            data_o => instr_data_o,
            full_o => prefetch_full,
            ready_o => open,
            instr_compressed_o => instr_compressed_o
        );
    prefetch_full_o <= prefetch_full; 

end architecture rtl;