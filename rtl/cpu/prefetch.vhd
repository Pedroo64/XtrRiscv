library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity prefetch is
    generic (
        G_PREFETCH_DEPTH : integer := 4
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        enable_i : in std_logic;
        flush_i : in std_logic;
        valid_i : in std_logic;
        instr_valid_i : in std_logic;
        instr_data_i : in std_logic_vector(31 downto 0);
        valid_o : out std_logic;
        data_o : out std_logic_vector(31 downto 0);
        full_o : out std_logic
    );
end entity prefetch;

architecture rtl of prefetch is
    signal fifo_flush : std_logic_vector(1 downto 0);
    signal fifo_we, fifo_re : std_logic_vector(1 downto 0);
    signal fifo_ef, fifo_ff : std_logic_vector(1 downto 0);
    signal fifo_wdat, fifo_rdat : std_logic_vector(31 downto 0);
    signal nxt_wcnt, wcnt, nxt_rcnt, rcnt : unsigned(integer(ceil(log2(real(G_PREFETCH_DEPTH)))) downto 0);
    signal load_wcnt, load_rcnt : std_logic;
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
    fifo_we <= (others => instr_valid_i);
    fifo_re <= not fifo_ef and (fifo_re'range => enable_i);

    data_o <= fifo_rdat;
    valid_o <= fifo_re(0);

    full_o <= '1' when enable_i = '0' and (wcnt(wcnt'left) xor rcnt(rcnt'left)) = '1' and wcnt(wcnt'left - 1  downto 0) = rcnt(rcnt'left - 1 downto 0) else '0';

    load_wcnt <= valid_i;
    load_rcnt <= fifo_re(0);

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

end architecture rtl;
