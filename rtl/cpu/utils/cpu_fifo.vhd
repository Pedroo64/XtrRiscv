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
        srst_i : in std_logic;
        we_i : in std_logic;
        wdata_i : in std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
        re_i : in std_logic;
        rdata_o : out std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
        empty_o : out std_logic;
        full_o : out std_logic
    );
end entity cpu_fifo;

architecture rtl of cpu_fifo is
    signal empty, full : std_logic;
begin
    gen_single_data: if G_FIFO_DEPTH = 1 generate
        signal data_q : std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
        signal wptr_q, rptr_q : std_logic;
    begin
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                wptr_q <= '0';
                rptr_q <= '0';
            elsif rising_edge(clk_i) then
                if srst_i = '1' or we_i = '1' then
                    wptr_q <= not srst_i and not wptr_q;
                end if;
                if srst_i = '1' or re_i = '1' then
                    rptr_q <= not srst_i and not rptr_q;
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if we_i = '1' then
                    data_q <= wdata_i;
                end if;
            end if;
        end process;
        empty     <= wptr_q xnor rptr_q;
        full      <= wptr_q xor  rptr_q;
        rdata_o   <= data_q;
    end generate gen_single_data;

    gen_multiple_data: if G_FIFO_DEPTH > 1 generate
        type fifo_buffer_t is array (0 to G_FIFO_DEPTH - 1) of std_logic_vector(G_FIFO_WIDTH - 1 downto 0);
        signal fifo_q : fifo_buffer_t;
        signal wptr_q, wptr, rptr_q, rptr : unsigned(integer(ceil(log2(real(G_FIFO_DEPTH)))) downto 0);
        signal load_wptr, load_rptr : std_logic;
        signal ptr_match : std_logic;
    begin
        load_wptr <= we_i or srst_i;
        load_rptr <= re_i or srst_i;
    
        wptr <= (others => '0') when srst_i = '1' else wptr_q + 1;
        rptr <= (others => '0') when srst_i = '1' else rptr_q + 1;
    
        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                wptr_q <= (others => '0');
                rptr_q <= (others => '0');
            elsif rising_edge(clk_i) then
                if load_wptr = '1' then
                    wptr_q <= wptr;
                end if;
                if load_rptr = '1' then
                    rptr_q <= rptr;
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if we_i = '1' then
                    fifo_q(to_integer(wptr_q(wptr_q'left - 1 downto 0))) <= wdata_i;
                end if;
            end if;
        end process;
        ptr_match <= '1' when wptr_q(wptr_q'left - 1 downto 0) = rptr_q(rptr_q'left - 1 downto 0) else '0';
        empty     <= (wptr_q(wptr_q'left) xnor rptr_q(rptr_q'left)) and ptr_match;
        full      <= (wptr_q(wptr_q'left) xor  rptr_q(rptr_q'left)) and ptr_match;
        rdata_o <= fifo_q(to_integer(rptr_q(rptr_q'left - 1 downto 0)));
    end generate gen_multiple_data;

    empty_o        <= empty;
    full_o         <= full;

end architecture rtl;