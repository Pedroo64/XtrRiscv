library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity cpu_fifo is
    generic (
        G_FIFO_DEPTH : integer := 16;
        G_FIFO_WIDTH : integer := 32
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        we_i : in std_logic;
        wdata_i : in std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
        re_i : in std_logic;
        rdata_o : out std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
        empty_o : out std_logic;
        full_o : out std_logic;
        next_full_o : out std_logic
    );
end entity cpu_fifo;

architecture rtl of cpu_fifo is
    type fifo_buffer_t is array (0 to G_FIFO_DEPTH - 1) of std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
    signal r_buffer : fifo_buffer_t;
    signal wptr, nxt_wptr, rptr, nxt_rptr : unsigned(integer(ceil(log2(real(G_FIFO_DEPTH)))) downto 0);
    signal load_wptr, load_rptr : std_logic;
    signal empty, full : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            wptr <= (others => '0');
            rptr <= (others => '0');
        elsif rising_edge(clk_i) then
            if load_wptr = '1' then
                wptr <= nxt_wptr;
            end if;
            if load_rptr = '1' then
                rptr <= nxt_rptr;
            end if;
        end if;
    end process;

    process (flush_i, wptr, rptr)
    begin
        if flush_i = '1' then
            nxt_wptr <= (others => '0');
            nxt_rptr <= (others => '0');
        else
            nxt_wptr <= wptr + 1;
            nxt_rptr <= rptr + 1;
        end if;
    end process;

    load_wptr <= flush_i or we_i;
    load_rptr <= flush_i or re_i;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if we_i = '1' then
                r_buffer(to_integer(wptr(wptr'left - 1 downto 0))) <= wdata_i;
            end if;
        end if;
    end process;

    empty <= '1' when wptr = rptr else '0';
    full  <= '1' when (wptr(wptr'left) xor rptr(rptr'left)) = '1' and wptr(wptr'left - 1 downto 0) = rptr(rptr'left - 1 downto 0) else '0';

    rdata_o <= r_buffer(to_integer(rptr(rptr'left - 1 downto 0)));
    empty_o <= empty;
    full_o <= full;
    
end architecture rtl;