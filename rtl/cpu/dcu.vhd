library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use IEEE.math_real.all;

entity dcu is
    generic (
        G_CACHE_SIZE : integer := 512;
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        cpu_adr_i : in std_logic_vector(31 downto 0);
        cpu_dat_i : in std_logic_vector(31 downto 0);
        cpu_siz_i : in std_logic_vector(31 downto 0);
        cpu_wr_i : in std_logic;
        cpu_vld_i : in std_logic;
        cpu_rdy_o : in std_logic;
        cpu_dat_o : out std_logic_vector(31 downto 0);
        cpu_vld_o : out std_logic;
        biu_adr_o : out std_logic_vector(31 downto 0);
        biu_dat_o : out std_logic_vector(31 downto 0);
        biu_wr_o : out std_logic;
        biu_vld_o : out std_logic;
        biu_rdy_i : in std_logic;
        biu_dat_i : in std_logic_vector(31 downto 0);
        biu_vld_i : in std_logic
    );
end entity dcu;

architecture rtl of dcu is
-- Cache
    constant C_ADDR_WIDTH : integer := integer(ceil(log2(real(G_CACHE_SIZE))));
    constant C_TAG_IWIDTH : integer := C_ADDR_WIDTH;
    constant C_TAG_IMIN : integer := 2;
    constant C_TAG_IMAX : integer := C_TAG_IWIDTH + C_TAG_IMIN - 1;
    constant C_TAG_DMAX : integer := 31;
    constant C_TAG_DMIN : integer := C_ADDR_WIDTH;
    constant C_TAG_DWIDTH : integer := C_TAG_DMAX - C_TAG_DMIN + 1 + 2; -- Size to store the address + dirty bit + valid bit;
    constant C_DATA_IWIDTH : integer := C_ADDR_WIDTH;
    constant C_DATA_IMIN : integer := 2;
    constant C_DATA_IMAX : integer := C_DATA_IWIDTH + C_DATA_IMIN - 1;
    signal cache_init_addr_q : std_logic_vector(C_TAG_IWIDTH downto 0);
    signal cache_init_done : std_logic;
    signal cache_tag_addr : std_logic_vector(C_TAG_IWIDTH - 1 downto 0);
    signal cache_tag_wdat, cache_tag_rdat : std_logic_vector(C_TAG_WIDTH - 1 downto 0);
    signal cache_tag_vld, cache_tag_wr : std_logic;
    signal cache_dat_addr : std_logic_vector(C_DATA_IWIDTH - 1 downto 0);
    signal cache_dat_wdat, cache_dat_rdat : std_logic_vector(31 downto 0);
    signal cache_dat_vld, cache_dat_wr : std_logic;
    signal cache_tag_match, cache_tag_hit, cache_tag_miss, cache_tag_dirty : std_logic;
    signal cache_tag_vld_q : std_logic;
    signal cache_cpu_addr_q : std_logic_vector(31 downto 0);
    signal cache_biu_alloc_vld, cache_cpu_vld, cache_stb_vld : std_logic;
    signal cache_cpu_rdy, cache_biu_alloc_rdy, cache_stb_rdy : std_logic;
    signal cache_priority_stb : std_logic;
-- STB
    type stb_state_t is (st_stb_idle, st_stb_tag_read, st_stb_write_data, st_stb_alloc_biu);
    signal stb_slot_nxt_state, stb_slot_state_q : stb_state_t;
    signal stb_slot_vld_q : std_logic;
    signal stb_slot_strb_q : std_logic_vector(3 downto 0);
    signal stb_slot_addr_q : std_logic_vector(31 downto 0);
    signal stb_slot_data_q : std_logic_vector(31 downto 0);
    signal stb_slot_dirty_q : std_logic;
    signal stb_full : std_logic;
    signal stb_tag_rd_vld, stb_tag_wr_vld, stb_dat_rd_vld, stb_dat_wr_vld : std_logic;
    signal stb_tag_rdy : std_logic;
    signal stb_alloc_biu_vld, stb_evict_biu_vld : std_logic;
    signal stb_alloc_biu_strb, stb_evict_biu_strb : std_logic_vector(3 downto 0);
-- BIU
    type biu_state_t is (st_biu_idle, st_biu_evict, st_biu_alloc);
    signal biu_nxt_state, biu_state_q : biu_state_t;
    signal biu_addr_q : std_logic_vector(31 downto 0);
    signal biu_data_q : std_logic_vector(31 downto 0);
    signal biu_valid_q, biu_dirty_q : std_logic;
    signal biu_strb_q : std_logic_vector(3 downto 0);
    signal biu_alloc_vld : std_logic;
begin

    -- Cache

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            cache_init_addr_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if cache_init_addr_q(cache_init_addr_q'left) = '0' then
                cache_init_addr_q <= cache_init_addr_q + 1;
            end if;
        end if;
    end process;

    cache_init_done <= cache_init_addr_q(cache_init_addr_q'left);

    cache_tag_addr <= cache_init_addr_q(C_TAG_IMAX downto C_TAG_IMIN) and (C_TAG_IWIDTH - 1 downto 0 => not cache_init_done)
                   or biu_addr_q(C_TAG_IMAX downto C_TAG_IMIN)        and (C_TAG_IWIDTH - 1 downto 0 =>     cache_biu_alloc_vld)
                   or cpu_adr_i(C_TAG_IMAX downto C_TAG_IMIN)         and (C_TAG_IWIDTH - 1 downto 0 =>     cache_cpu_vld)
                   or stb_slot_addr_q(C_TAG_IMAX downto C_TAG_IMIN)   and (C_TAG_IWIDTH - 1 downto 0 =>     cache_stb_vld)
                   ;

    cache_tag_wdat <= (biu_addr_q(C_TAG_DMAX downto C_TAG_DMIN)      & biu_dirty_q & biu_valid_q) and (C_TAG_DWIDTH - 1 downto 0 => cache_init_done and biu_alloc_vld)
                   or (stb_slot_addr_q(C_TAG_DMAX downto C_TAG_DMIN) & "11")                      and (C_TAG_DWIDTH - 1 downto 0 => cache_init_done and stb_tag_wr_vld)
                   ;

    cache_tag_wr   <= not cache_init_done or biu_alloc_vld or stb_tag_wr_vld;

    cache_tag_vld  <= not cache_init_done or biu_alloc_vld or stb_tag_wr_vld or stb_tag_rd_vld or cpu_vld_i;

    cache_dat_addr <= biu_addr_q(C_DATA_IMAX downto C_DATA_IMIN)      and (C_DATA_IWIDTH - 1 downto 0 =>     biu_alloc_vld)
                   or cpu_adr_i(C_DATA_IMAX downto C_DATA_IMIN)       and (C_DATA_IWIDTH - 1 downto 0 => not biu_alloc_vld and     cpu_vld_i)
                   or stb_slot_addr_q(C_DATA_IMAX downto C_DATA_IMIN) and (C_DATA_IWIDTH - 1 downto 0 => not biu_alloc_vld and not cpu_vld_i and (stb_dat_wr_vld or stb_dat_rd_vld))
                   ;

    cache_dat_wdat <= biu_data_q      and (31 downto 0 =>     biu_alloc_vld)
                   or stb_slot_data_q and (31 downto 0 => not biu_alloc_vld and stb_dat_wr_vld)
                   ;

    cache_dat_wr   <= biu_alloc_vld or stb_dat_wr_vld;

    cache_dat_vld  <= biu_alloc_vld or stb_dat_wr_vld or stb_dat_rd_vld;

    cache_priority_stb  <= cpu_vld_i and cpu_wr_i and stb_full;

    cache_biu_alloc_vld <= cache_init_done and biu_alloc_vld;
    cache_cpu_vld       <= not cache_biu_alloc_vld and cpu_vld_i and not cache_priority_stb;
    cache_stb_vld       <= not cache_cpu_vld and stb_dat_wr_vld;


    cache_biu_alloc_rdy <= cache_init_done;
    cache_cpu_rdy       <= cache_init_done and not biu_alloc_vld and not cache_priority_stb;
    cache_stb_rdy       <= cache_init_done and not biu_alloc_vld and (not cpu_vld_i or cache_priority_stb);

    u_tag_ram : entity work.bram
        generic map (
            G_DEPTH => G_CACHE_SIZE,
            G_ADDR_WIDTH => C_TAG_IWIDTH,
            G_DATA_WIDTH => C_TAG_WIDTH,
            G_BYTE_WIDTH => C_TAG_WIDTH,
            G_INIT_FILE => "none"
        )
        port map (
            clk_i => clk_i,
            adr_i => cache_tag_addr,
            en_i => cache_tag_vld,
            we_i => cache_tag_wr,
            be_i => (others => '1'),
            dat_i => cache_tag_wdat,
            dat_o => cache_tag_rdat
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
            adr_i => cache_dat_addr,
            en_i => cache_dat_vld,
            we_i => cache_dat_wr,
            be_i => (others => '1'),
            dat_i => cache_dat_wdat,
            dat_o => cache_dat_rdat
        );

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if cpu_vld_i = '1' then
                cache_cpu_addr_q <= cpu_adr_i;
            end if;
            cache_tag_vld_q <= cache_tag_vld and not cache_tag_wr;
        end if;
    end process;

    cache_tag_match <= '1' when cache_tag_rdat(0) = '1' and cache_cpu_addr_q(C_TAG_DMAX downto C_TAG_DMIN) = cache_tag_rdat(cache_tag_rdat'left downto 2) else '0';
    cache_tag_hit   <= cache_tag_vld_q and     cache_tag_match;
    cache_tag_miss  <= cache_tag_vld_q and not cache_tag_match;
    cache_tag_dirty <= cache_tag_rdat(1);

    -- STB
    process (all)
    begin
        case stb_slot_state_q is
            when st_stb_idle =>
                if cpu_vld_i = '1' and cpu_wr_i = '1' then
                    stb_slot_nxt_state <= st_stb_tag_read;
                else
                    stb_slot_nxt_state <= st_stb_idle;
                end if;
            when st_stb_tag_read =>
                if cache_tag_hit = '1' then
                    stb_slot_nxt_state <= st_stb_write_data;
                else
                    stb_slot_nxt_state <= st_stb_merge_biu;
                end if;
            when st_stb_write_data =>
                if stb_dat_wr_vld = '1' or stb_evict_biu_vld = '1' then
                    stb_slot_nxt_state <= st_stb_idle;
                else
                    stb_slot_nxt_state <= st_stb_write_data;
                end if;
            when st_stb_alloc_biu =>
                if stb_alloc_biu_vld = '1' then
                    stb_slot_nxt_state <= st_stb_idle;
                else
                    stb_slot_nxt_state <= st_stb_merge_biu;
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

    stb_evict_biu_vld <= '1' when stb_slot_vld_q = '1' and cache_tag_miss = '1' and stb_slot_addr_q(C_TAG_DMAX downto C_TAG_DMIN) = cache_cpu_addr_q else '0';
    stb_alloc_biu_vld <= '1' when stb_slot_state_q = st_stb_alloc_biu and biu_state_q = st_biu_alloc else '0';
    stb_tag_rd_vld    <= '0';
    stb_tag_wr_vld    <= '1' when stb_slot_state_q = st_stb_write_data and stb_slot_dirty_q = '0' else '0';
    stb_dat_rd_vld    <= '0';
    stb_dat_wr_vld    <= '1' when stb_slot_state_q = st_stb_write_data else '0';

    -- BIU
    process ()
    begin
        case biu_state_q is
            when st_biu_idle =>
                if    cache_tag_vld_q = '1' and cache_tag_match = '1' then
                    biu_nxt_state <= st_biu_evict;
                elsif cache_tag_vld_q = '1' and cache_tag_match = '0' then
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

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            case biu_state_q is
                when st_biu_idle =>
                    biu_addr_q <= cache_tag_rdat & cache_cpu_addr_q(C_TAG_DMAX downto C_TAG_DMIN);
                    biu_data_q <= cache_dat_rdat;
                    biu_strb_q <= (others => '0');
                    biu_dirty_q <= '0';
                    biu_valid_q <= '0';
                when st_biu_alloc =>
                    biu_addr_q <= cache_cpu_addr_q;
                    if biu_vld_i = '1' then
                        for i in 0 to 3 loop
                            biu_data_q((i+1)*8 - 1 downto i*8) <= biu_dat_i((i+1)*8 - 1 downto i*8);
                        end loop;
                    end if;
                when others =>


            end case;
        end if;
    end process;

end architecture rtl;