library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity prefetch is
    generic (
        G_PREFETCH_DEPTH : integer := 4;
        G_EXTENSION_C : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        enable_i : in std_logic;
        flush_i : in std_logic;
        valid_i : in std_logic;
        instr_valid_i : in std_logic;
        instr_data_i : in std_logic_vector(31 downto 0);
        load_pc_i : in std_logic;
        pc_align_i : in std_logic;
        valid_o : out std_logic;
        data_o : out std_logic_vector(31 downto 0);
        full_o : out std_logic;
        ready_o : out std_logic;
        instr_compressed_o : out std_logic
    );
end entity prefetch;

architecture rtl of prefetch is
    signal fifo_flush : std_logic_vector(1 downto 0);
    signal fifo_we, fifo_re : std_logic_vector(1 downto 0);
    signal fifo_ef, fifo_ff : std_logic_vector(1 downto 0);
    signal fifo_wdat, fifo_rdat : std_logic_vector(31 downto 0);
    signal nxt_wcnt, wcnt, nxt_rcnt, rcnt : unsigned(integer(ceil(log2(real(G_PREFETCH_DEPTH)))) downto 0);
    signal load_wcnt, load_rcnt : std_logic;
    signal prefetch_valid, prefetch_full : std_logic;
-- Dispatch
    signal word_unalign : std_logic;
    signal pc_align, instr_compressed : std_logic;
begin

    fifo_wdat <= instr_data_i;
    gen_prefetch_buffer: for i in 0 to 1 generate
        u_prefetch_buffer : entity work.cpu_fifo
            generic map (
                G_FIFO_DEPTH => G_PREFETCH_DEPTH,
                G_FIFO_WIDTH => 16
            )
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                flush_i => fifo_flush(i),
                we_i => fifo_we(i),
                wdata_i => fifo_wdat(i*16 + 15 downto i*16),
                re_i => fifo_re(i),
                rdata_o => fifo_rdat(i*16 + 15 downto i*16),
                empty_o => fifo_ef(i),
                full_o => fifo_ff(i)
            );
    end generate gen_prefetch_buffer;

    fifo_flush <= (others => flush_i);
    fifo_we(0) <= instr_valid_i and not word_unalign;
    fifo_we(1) <= instr_valid_i;

    prefetch_valid <= '1' when unsigned(fifo_re) /= 0 else '0';

    data_o <= fifo_rdat(15 downto 0) & fifo_rdat(31 downto 16) when pc_align = '1' else fifo_rdat;
    valid_o <= prefetch_valid;

    prefetch_full <= '1' when fifo_re(1) = '0' and (wcnt(wcnt'left) xor rcnt(rcnt'left)) = '1' and wcnt(wcnt'left - 1  downto 0) = rcnt(rcnt'left - 1 downto 0) else '0';
    full_o <= prefetch_full;
    ready_o <= not prefetch_full;

    load_wcnt <= valid_i or flush_i;
    load_rcnt <= fifo_re(1) or flush_i;

    process (flush_i, wcnt, rcnt)
    begin
        if flush_i = '1' then
            nxt_wcnt <= (others => '0');
            nxt_rcnt <= (others => '0');
        else
            nxt_wcnt <= wcnt + 1;
            nxt_rcnt <= rcnt + 1;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if load_wcnt = '1' then
                wcnt <= nxt_wcnt;
            end if;
            if load_rcnt = '1' then
                rcnt <= nxt_rcnt;
            end if;
        end if;
    end process;

-- DISPATCH
    gen_dispatch_without_compress: if G_EXTENSION_C = FALSE generate
        instr_compressed <= '0';
        pc_align <= '0';
        word_unalign <= '0';
        fifo_re(0) <= enable_i and not fifo_ef(0);
        fifo_re(1) <= enable_i and not fifo_ef(1);
    end generate gen_dispatch_without_compress;
    gen_dispatch_with_compress: if G_EXTENSION_C = TRUE generate
        instr_compressed <= '1' when (pc_align = '1' and fifo_rdat(17 downto 16) /= "11") or (pc_align = '0' and fifo_rdat(1 downto 0) /= "11") else '0';
        fifo_re(0) <= 
            '1' when enable_i = '1' and fifo_ef(0) = '0' and pc_align = '0' and fifo_rdat(1 downto 0) /= "11" else
            '1' when enable_i = '1' and fifo_ef = "00" and instr_compressed = '0' else
            '0';
        fifo_re(1) <= 
            '1' when enable_i = '1' and fifo_ef(1) = '0' and pc_align = '1' and fifo_rdat(17 downto 16) /= "11" else
            '1' when enable_i = '1' and fifo_ef = "00" and instr_compressed = '0' else
            '0';
        
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if load_pc_i = '1' then
                    pc_align <= pc_align_i;
                elsif prefetch_valid = '1' and instr_compressed = '1' then
                    pc_align <= not pc_align;
                end if;
            end if;
        end process;
        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if load_pc_i = '1' then
                    word_unalign <= pc_align_i;
                elsif instr_valid_i = '1' then
                    word_unalign <= '0';
                end if;
            end if;
        end process;
    end generate gen_dispatch_with_compress;
    instr_compressed_o <= instr_compressed;

end architecture rtl;
