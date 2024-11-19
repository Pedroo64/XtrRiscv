library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use IEEE.math_real.all;

entity dcu is
    generic (
        G_CACHE_SIZE : integer := 512;
        G_MEM_ADDR_WIDTH : integer := 32
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        cpu_adr_i : in std_logic_vector(G_MEM_ADDR_WIDTH - 1 downto 0);
        cpu_dat_i : in std_logic_vector(31 downto 0);
        cpu_siz_i : in std_logic_vector(3 downto 0);
        cpu_wr_i : in std_logic;
        cpu_vld_i : in std_logic;
        cpu_rdy_o : out std_logic;
        cpu_dat_o : out std_logic_vector(31 downto 0);
        cpu_vld_o : out std_logic;
        biu_adr_o : out std_logic_vector(G_MEM_ADDR_WIDTH - 1 downto 0);
        biu_dat_o : out std_logic_vector(31 downto 0);
        biu_wr_o : out std_logic;
        biu_vld_o : out std_logic;
        biu_rdy_i : in std_logic;
        biu_dat_i : in std_logic_vector(31 downto 0);
        biu_vld_i : in std_logic
    );
end entity dcu;

architecture rtl of dcu is
-- Signals
    signal cpu_vld, cpu_vld_q : std_logic;
    signal cpu_miss, cpu_miss_q : std_logic;
    signal stb_miss, stb_miss_q : std_logic;
-- Cache
    constant C_ADDR_WIDTH : integer := integer(ceil(log2(real(G_CACHE_SIZE))));
    constant C_TAG_IWIDTH : integer := C_ADDR_WIDTH;
    constant C_TAG_IMIN : integer := 2;
    constant C_TAG_IMAX : integer := C_TAG_IWIDTH + C_TAG_IMIN - 1;
    constant C_TAG_DMAX : integer := G_MEM_ADDR_WIDTH - 1;
    constant C_TAG_DMIN : integer := C_ADDR_WIDTH + 2;
    constant C_TAG_DWIDTH : integer := C_TAG_DMAX - C_TAG_DMIN + 1 + 2; -- Size to store the address + dirty bit + valid bit;
    constant C_DATA_IWIDTH : integer := C_ADDR_WIDTH;
    constant C_DATA_IMIN : integer := 2;
    constant C_DATA_IMAX : integer := C_DATA_IWIDTH + C_DATA_IMIN - 1;
    type tag_ram_t is record
        addr : std_logic_vector(C_TAG_IWIDTH - 1 downto 0);
        wdat, rdat : std_logic_vector(C_TAG_DWIDTH - 1 downto 0);
        vld, wr : std_logic;
    end record;
    type data_ram_t is record
        addr : std_logic_vector(C_DATA_IWIDTH - 1 downto 0);
        wdat, rdat : std_logic_vector(31 downto 0);
        vld, wr : std_logic;
    end record;
    signal tag_ram : tag_ram_t;
    signal data_ram : data_ram_t;

    signal cache_init_addr_q : std_logic_vector(C_TAG_IWIDTH downto 0);
    signal cache_init_done : std_logic;
    signal cache_vld_q : std_logic;
    signal cache_tag_addr : std_logic_vector(C_TAG_DMAX downto C_TAG_DMIN);
    signal cache_tag_match, cache_tag_hit, cache_tag_miss, cache_tag_dirty : std_logic;
    signal cache_tag_vld : std_logic;
    signal cache_cpu_addr_q : std_logic_vector(G_MEM_ADDR_WIDTH - 1 downto 0);
    signal cache_biu_vld, cache_cpu_vld, cache_stb_vld : std_logic;
    signal cache_cpu_rdy, cache_biu_rdy, cache_stb_rdy : std_logic;
    signal cache_priority_stb : std_logic;
-- STB
    type stb_state_t is (st_stb_idle, st_stb_tag_read, st_stb_write_data, st_stb_alloc_biu);
    signal stb_slot_wr : std_logic;
    signal stb_slot_nxt_state, stb_slot_state_q : stb_state_t;
    signal stb_slot_vld_set, stb_slot_vld_clr : std_logic;
    signal stb_slot_vld_q : std_logic;
    signal stb_slot_strb_q : std_logic_vector(3 downto 0);
    signal stb_slot_addr_q : std_logic_vector(G_MEM_ADDR_WIDTH - 1 downto 0);
    signal stb_slot_data_q : std_logic_vector(31 downto 0);
    signal stb_slot_dirty_q : std_logic;
    signal stb_full : std_logic;
    signal stb_tag_wr_vld, stb_dat_wr_vld : std_logic;
    signal stb_tag_rdy : std_logic;
    signal stb_alloc_biu_vld, stb_evict_biu_vld : std_logic;
    signal stb_alloc_biu_strb, stb_evict_biu_strb : std_logic_vector(3 downto 0);
    signal stb_index_match, stb_tag_match : std_logic;
    signal stb_index_hit, stb_tag_hit, stb_hit : std_logic;
-- BIU
    type biu_state_t is (st_biu_idle, st_biu_evict, st_biu_alloc);
    signal biu_nxt_state, biu_state_q : biu_state_t;
    signal biu_addr, biu_addr_q : std_logic_vector(G_MEM_ADDR_WIDTH - 1 downto 0);
    signal biu_data, biu_data_q : std_logic_vector(31 downto 0);
    signal biu_dirty, biu_dirty_q, biu_alloc_valid_q : std_logic;
    signal biu_valid_set, biu_valid_clr, biu_valid_q : std_logic;
    signal biu_strb, biu_strb_q : std_logic_vector(3 downto 0);
    signal biu_alloc_vld : std_logic;
begin

    -- Cache

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            cache_init_addr_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if cache_init_addr_q(cache_init_addr_q'left) = '0' then
                cache_init_addr_q <= std_logic_vector(unsigned(cache_init_addr_q) + 1);
            end if;
        end if;
    end process;

    cache_init_done <= cache_init_addr_q(cache_init_addr_q'left);

    tag_ram.addr   <= (cache_init_addr_q(C_TAG_IWIDTH - 1 downto 0)    and (C_TAG_IWIDTH - 1 downto 0 => not cache_init_done))
                   or (biu_addr_q(C_TAG_IMAX downto C_TAG_IMIN)        and (C_TAG_IWIDTH - 1 downto 0 =>     cache_biu_vld))
                   or (cpu_adr_i(C_TAG_IMAX downto C_TAG_IMIN)         and (C_TAG_IWIDTH - 1 downto 0 =>     cache_cpu_vld))
                   or (stb_slot_addr_q(C_TAG_IMAX downto C_TAG_IMIN)   and (C_TAG_IWIDTH - 1 downto 0 =>     cache_stb_vld))
                   ;

    tag_ram.wdat   <= ((biu_addr_q(C_TAG_DMAX downto C_TAG_DMIN)      & biu_dirty_q & biu_valid_q) and (C_TAG_DWIDTH - 1 downto 0 => cache_biu_vld))
                   or ((stb_slot_addr_q(C_TAG_DMAX downto C_TAG_DMIN) & "11")                      and (C_TAG_DWIDTH - 1 downto 0 => cache_stb_vld))
                   ;

    tag_ram.wr     <= not cache_init_done or cache_biu_vld or (stb_tag_wr_vld and cache_stb_vld);

    tag_ram.vld    <= not cache_init_done or cache_biu_vld or (stb_tag_wr_vld and cache_stb_vld) or cache_cpu_vld;

    data_ram.addr  <= (biu_addr_q(C_DATA_IMAX downto C_DATA_IMIN)      and (C_DATA_IWIDTH - 1 downto 0 => cache_biu_vld))
                   or (cpu_adr_i(C_DATA_IMAX downto C_DATA_IMIN)       and (C_DATA_IWIDTH - 1 downto 0 => cache_cpu_vld))
                   or (stb_slot_addr_q(C_DATA_IMAX downto C_DATA_IMIN) and (C_DATA_IWIDTH - 1 downto 0 => cache_stb_vld))
                   ;

    data_ram.wdat  <= (biu_data_q      and (31 downto 0 =>     cache_biu_vld))
                   or (stb_slot_data_q and (31 downto 0 =>     cache_stb_vld))
                   ;

    data_ram.wr   <= biu_alloc_vld or cache_stb_vld;

    data_ram.vld  <= biu_alloc_vld or cache_cpu_vld or cache_stb_vld;

    cache_priority_stb  <= cpu_vld_i and cpu_wr_i and stb_full;

    cache_biu_vld <= biu_alloc_vld;
    cache_cpu_vld       <=
        '1' when cache_init_done = '1' and biu_state_q = st_biu_idle and cpu_vld_i = '1' and cache_tag_miss = '0' and biu_alloc_vld = '0' and cache_priority_stb = '0' else
        '0';
    cache_stb_vld       <=
        '1' when cache_init_done = '1' and (cpu_vld_i = '0' or cache_priority_stb = '1' or cpu_miss_q = '1') and biu_alloc_vld = '0' and stb_dat_wr_vld = '1' else
        '0';


    cache_biu_rdy <= cache_init_done;
    cache_cpu_rdy <=
        '0' when cache_init_done = '0' or biu_alloc_vld = '1' or cache_priority_stb = '1' or biu_state_q /= st_biu_idle or cache_tag_miss = '1' else
        '1';
    cache_stb_rdy <=
        '0' when cache_init_done = '0' or biu_alloc_vld = '1' or not (cpu_vld_i = '0' or cache_priority_stb = '1' or cpu_miss_q = '1') else
        '1';

    u_tag_ram : entity work.bram
        generic map (
            G_DEPTH => G_CACHE_SIZE,
            G_ADDR_WIDTH => C_TAG_IWIDTH,
            G_DATA_WIDTH => C_TAG_DWIDTH,
            G_BYTE_WIDTH => C_TAG_DWIDTH,
            G_INIT_FILE => "none"
        )
        port map (
            clk_i => clk_i,
            adr_i => tag_ram.addr,
            en_i => tag_ram.vld,
            we_i => tag_ram.wr,
            be_i => (others => '1'),
            dat_i => tag_ram.wdat,
            dat_o => tag_ram.rdat
        );

    u_data_ram : entity work.bram
        generic map (
            G_DEPTH => G_CACHE_SIZE,
            G_ADDR_WIDTH => C_DATA_IWIDTH,
            G_DATA_WIDTH => 32,
            G_BYTE_WIDTH => 32,
            G_INIT_FILE => "none"
        )
        port map (
            clk_i => clk_i,
            adr_i => data_ram.addr,
            en_i => data_ram.vld,
            we_i => data_ram.wr,
            be_i => (others => '1'),
            dat_i => data_ram.wdat,
            dat_o => data_ram.rdat
        );

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if cache_cpu_vld = '1' then
                cache_cpu_addr_q <= cpu_adr_i;
            end if;
            cache_vld_q <= tag_ram.vld and not tag_ram.wr;
        end if;
    end process;

    cache_tag_addr  <= tag_ram.rdat(tag_ram.rdat'left downto 2);
    cache_tag_dirty <= tag_ram.rdat(1);
    cache_tag_vld   <= tag_ram.rdat(0);
    cache_tag_match <= '1' when cache_cpu_addr_q(C_TAG_DMAX downto C_TAG_DMIN) = cache_tag_addr else '0';
    cache_tag_hit   <= cache_vld_q and      cache_tag_match and cache_tag_vld;
    cache_tag_miss  <= cache_vld_q and not (cache_tag_match and cache_tag_vld);

    -- STB

    stb_slot_wr <= cpu_vld_i and cpu_wr_i and cache_cpu_rdy;

    process (stb_slot_state_q, stb_slot_wr, cache_tag_hit, stb_dat_wr_vld, cache_stb_rdy, stb_evict_biu_vld, stb_alloc_biu_vld)
    begin
        case stb_slot_state_q is
            when st_stb_idle =>
                if stb_slot_wr = '1' then
                    stb_slot_nxt_state <= st_stb_tag_read;
                else
                    stb_slot_nxt_state <= st_stb_idle;
                end if;
            when st_stb_tag_read =>
                if cache_tag_hit = '1' then
                    stb_slot_nxt_state <= st_stb_write_data;
                else
                    stb_slot_nxt_state <= st_stb_alloc_biu;
                end if;
            when st_stb_write_data =>
                if (stb_dat_wr_vld = '1' and cache_stb_rdy = '1') or stb_evict_biu_vld = '1' then
                    stb_slot_nxt_state <= st_stb_idle;
                else
                    stb_slot_nxt_state <= st_stb_write_data;
                end if;
            when st_stb_alloc_biu =>
                if stb_alloc_biu_vld = '1' then
                    stb_slot_nxt_state <= st_stb_idle;
                else
                    stb_slot_nxt_state <= st_stb_alloc_biu;
                end if;
            when others =>
        end case;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            stb_slot_state_q <= st_stb_idle;
        elsif rising_edge(clk_i) then
            stb_slot_state_q <= stb_slot_nxt_state;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            stb_slot_vld_q <= '0';
        elsif rising_edge(clk_i) then
            case stb_slot_state_q is
                when st_stb_idle       => if stb_slot_wr = '1'                                                         then stb_slot_vld_q <= '1'; end if;
                when st_stb_write_data => if (stb_dat_wr_vld = '1' and cache_stb_rdy = '1') or stb_evict_biu_vld = '1' then stb_slot_vld_q <= '0'; end if;
                when st_stb_alloc_biu  => if stb_alloc_biu_vld = '1'                                                   then stb_slot_vld_q <= '0'; end if;
                when others =>
            end case;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if stb_slot_state_q = st_stb_idle then
                stb_slot_addr_q <= cpu_adr_i;
                stb_slot_data_q <= cpu_dat_i;
                stb_slot_strb_q <= cpu_siz_i;
            end if;
            if stb_slot_state_q = st_stb_tag_read then
                for i in stb_slot_strb_q'range loop
                    if stb_slot_strb_q(i) = '0' then
                        stb_slot_data_q((i+1)*8-1 downto i*8) <= data_ram.rdat((i+1)*8-1 downto i*8);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    stb_index_match   <= '1' when stb_slot_addr_q(C_TAG_IMAX downto C_TAG_IMIN) = cache_cpu_addr_q(C_TAG_IMAX downto C_TAG_IMIN) else '0';
    stb_tag_match     <= '1' when stb_slot_addr_q(C_TAG_DMAX downto C_TAG_DMIN) = cache_tag_addr else '0';
    stb_index_hit     <= stb_slot_vld_q and stb_index_match;
    stb_tag_hit       <= stb_slot_vld_q and stb_tag_match and cache_tag_vld and cache_vld_q;
    stb_hit           <= stb_index_hit and stb_tag_hit;

    stb_evict_biu_vld <= '1' when stb_slot_state_q = st_stb_write_data and stb_index_hit = '1' and cache_tag_match = '0' and cache_tag_vld = '1' and cache_vld_q = '1' else '0';
    stb_alloc_biu_vld <= '1' when stb_slot_state_q = st_stb_alloc_biu and biu_state_q = st_biu_alloc else '0';
    stb_tag_wr_vld    <= '1' when stb_slot_state_q = st_stb_write_data and stb_slot_dirty_q = '0' else '0';
    stb_dat_wr_vld    <= '1' when stb_slot_state_q = st_stb_write_data else '0';

    stb_full <= '1' when stb_slot_state_q /= st_stb_idle else '0';

    stb_slot_dirty_q <= '0';

    -- BIU
    process (biu_state_q, cache_tag_miss, cache_tag_dirty, biu_rdy_i, biu_vld_i, stb_index_hit)
    begin
        case biu_state_q is
            when st_biu_idle =>
                if    cache_tag_miss = '1' and (cache_tag_dirty = '1' or stb_index_hit = '1') then
                    biu_nxt_state <= st_biu_evict;
                elsif cache_tag_miss = '1' and cache_tag_dirty = '0' then
                    biu_nxt_state <= st_biu_alloc;
                else
                    biu_nxt_state <= st_biu_idle;
                end if;
            when st_biu_evict =>
                if biu_rdy_i = '1' then
                    biu_nxt_state <= st_biu_alloc;
                else
                    biu_nxt_state <= st_biu_evict;
                end if;
            when st_biu_alloc =>
                if biu_vld_i = '1' then
                    biu_nxt_state <= st_biu_idle;
                else
                    biu_nxt_state <= st_biu_alloc;
                end if;
            when others =>
        end case;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            biu_state_q <= st_biu_idle;
        elsif rising_edge(clk_i) then
            biu_state_q <= biu_nxt_state;
        end if;
    end process;

    biu_addr <=
        cache_tag_addr & cache_cpu_addr_q(C_TAG_DMIN-1 downto 2) & "00" when cache_tag_miss = '1' and (cache_tag_dirty = '1' or stb_index_hit = '1') else
        cache_cpu_addr_q(cache_cpu_addr_q'left downto 2) & "00";

    gen_biu_data: for i in 0 to 3 generate
        biu_data((i+1)*8-1 downto i*8) <=
            stb_slot_data_q((i+1)*8-1 downto i*8) when stb_index_hit = '1' or (stb_slot_state_q = st_stb_alloc_biu and stb_slot_strb_q(i) = '1') else
            data_ram.rdat((i+1)*8-1 downto i*8)   when cache_vld_q = '1' and cache_tag_dirty = '1' else
            biu_dat_i((i+1)*8 - 1 downto i*8)     when biu_strb_q(i) = '0' else
            biu_data_q((i+1)*8 - 1 downto i*8);
    end generate gen_biu_data;

    biu_strb <=
        stb_slot_strb_q when stb_slot_state_q = st_stb_alloc_biu else
        (others => '0');

    biu_dirty <=
        '1' when stb_slot_state_q = st_stb_alloc_biu else
        '0';

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if (biu_state_q = st_biu_idle and cache_tag_miss = '1') or (biu_state_q = st_biu_evict and biu_rdy_i = '1') then
                biu_addr_q <= biu_addr;
            end if;
            if biu_state_q = st_biu_idle or (biu_state_q = st_biu_alloc and (stb_alloc_biu_vld = '1' or biu_vld_i = '1')) then
                biu_data_q <= biu_data;
            end if;
            if biu_state_q = st_biu_idle or (biu_state_q = st_biu_alloc and stb_alloc_biu_vld = '1') then
                biu_strb_q  <= biu_strb;
                biu_dirty_q <= biu_dirty;
            end if;
        end if;
    end process;

    biu_valid_set <= '1' when cache_tag_miss = '1' or biu_vld_i = '1' else '0';
    biu_valid_clr <= '1' when (biu_state_q = st_biu_alloc and biu_rdy_i = '1') or biu_state_q = st_biu_idle else '0';

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            biu_valid_q <= '0';
        elsif rising_edge(clk_i) then
            if biu_valid_set = '1' or biu_valid_clr = '1' then
                biu_valid_q <= biu_valid_set;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            biu_alloc_valid_q <= '0';
        elsif rising_edge(clk_i) then
            if biu_state_q = st_biu_alloc and biu_vld_i = '1' then
                biu_alloc_valid_q <= '1';
            else
                biu_alloc_valid_q <= '0';
            end if;
        end if;
    end process;

    biu_alloc_vld <= biu_alloc_valid_q;

    biu_adr_o <= biu_addr_q;
    biu_dat_o <= biu_data_q;
    biu_vld_o <= biu_valid_q when biu_state_q = st_biu_evict or biu_state_q = st_biu_alloc else '0';
    biu_wr_o  <= '1' when biu_state_q = st_biu_evict else '0';

    -- Control

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            cpu_miss_q <= '0';
            cpu_vld_q <= '0';
        elsif rising_edge(clk_i) then
            cpu_vld_q <= cpu_vld_i and not cpu_wr_i and cache_cpu_rdy;
            if cpu_miss_q = '0' and cpu_vld_q = '1' and cache_tag_miss = '1' then
                cpu_miss_q <= '1';
            elsif cpu_miss_q = '1' and biu_alloc_vld = '1' then
                cpu_miss_q <= '0';
            end if;
        end if;
    end process;

    cpu_rdy_o <= cache_cpu_rdy;

    cpu_vld_o <=
        '1' when cpu_vld_q = '1' and cache_tag_hit = '1' else
        '1' when cpu_miss_q = '1' and biu_alloc_vld = '1' else
        '0';

    cpu_dat_o <=
        stb_slot_data_q when stb_hit = '1' else
        biu_data_q      when cpu_miss_q = '1' else
        data_ram.rdat   when cache_vld_q = '1' else
        (others => 'X');

end architecture rtl;
