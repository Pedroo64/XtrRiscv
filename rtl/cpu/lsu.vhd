library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity lsu is
    generic (
        G_TWO_CYCLES_READ : boolean := FALSE;
        G_CATCH_MISALIGNED : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        flush_i : in std_logic;
        address_i : in std_logic_vector(31 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        load_i : in std_logic;
        store_i : in std_logic;
        size_i : in std_logic_vector(2 downto 0);
        data_o : out std_logic_vector(31 downto 0);
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_dat_o : out std_logic_vector(31 downto 0);
        cmd_siz_o : out std_logic_vector(1 downto 0);
        cmd_vld_o : out std_logic;
        cmd_we_o : out std_logic;
        cmd_rdy_i : in std_logic;
        rsp_dat_i : in std_logic_vector(31 downto 0);
        rsp_vld_i : in std_logic;
        cmd_rdy_o : out std_logic;
        rsp_rdy_o : out std_logic;
        load_misaligned_o : out std_logic;
        store_misaligned_o : out std_logic
    );
end entity lsu;

architecture rtl of lsu is
    signal cmd_rdy, rsp_rdy : std_logic;
    signal address_misaligned : std_logic;
begin

    address_misaligned <= (size_i(0) and address_i(0)) or (size_i(1) and (address_i(1) or address_i(0))) when G_CATCH_MISALIGNED = TRUE else '0'; 

    gen_one_cycle_read: if G_TWO_CYCLES_READ = FALSE generate
        signal valid : std_logic;
        signal load_q : std_logic;
    begin

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                load_q <= '0';
            elsif rising_edge(clk_i) then
                if enable_i = '1' then
                    load_q <= valid_i and load_i and not flush_i and cmd_rdy_i;
                end if;
            end if;
        end process;

        valid <= enable_i and valid_i and not flush_i;
        cmd_rdy <= '0' when valid = '1' and cmd_rdy_i = '0' else '1';
        rsp_rdy <= '0' when load_q = '1' and rsp_vld_i = '0' else '1';

        -- bus interface
        cmd_adr_o <= address_i;
        cmd_dat_o <= data_i;
        cmd_siz_o <= size_i(1 downto 0);
        cmd_vld_o <= valid and not address_misaligned;
        cmd_we_o <= store_i;
        data_o <= rsp_dat_i when load_q = '1' else (others => '-');
    end generate gen_one_cycle_read;

    gen_two_cycle_read: if G_TWO_CYCLES_READ = TRUE generate
        signal enable : std_logic;
        signal address_q, data_q : std_logic_vector(31 downto 0);
        signal size_q : std_logic_vector(1 downto 0);
        signal cmd_valid_q, valid_q, load_q, store_q : std_logic;
        signal stall, stall_q : std_logic;
    begin

        stall  <=
            '1' when valid_q = '1' and cmd_rdy_i = '0' else
            '1' when valid_q = '1' and load_q = '1' and stall_q = '0' else
            '1' when valid_q = '1' and load_q = '1' and stall_q = '1' and rsp_vld_i = '0' else
            '0';

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                stall_q <= stall;
            end if;
        end process;

        enable <= enable_i and not stall;

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                valid_q <= '0';
                cmd_valid_q <= '0';
            elsif rising_edge(clk_i) then
                if enable = '1' then
                    valid_q <= valid_i and not flush_i and not address_misaligned;
                    cmd_valid_q <= valid_i and not flush_i and not address_misaligned;
                elsif cmd_rdy = '1' then
                    cmd_valid_q <= '0';
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if enable = '1' then
                    load_q  <= load_i;
                    store_q <= store_i;
                    address_q <= address_i;
                    data_q <= data_i;
                    size_q <= size_i(1 downto 0);
                end if;
            end if;
        end process;

        cmd_rdy <= '0' when valid_q = '1' and cmd_rdy_i = '0' else '1';
        rsp_rdy <=
            '0' when valid_q = '1' and load_q = '1' and stall_q = '0' else
            '0' when valid_q = '1' and load_q = '1' and stall_q = '1' and rsp_vld_i = '0' else
            '1';

        cmd_adr_o <= address_q;
        cmd_dat_o <= data_q;
        cmd_siz_o <= size_q;
        cmd_vld_o <= cmd_valid_q;
        cmd_we_o  <= store_q;

        data_o <= rsp_dat_i when load_q = '1' else (others => '-');

    end generate gen_two_cycle_read;

    cmd_rdy_o <= cmd_rdy;
    rsp_rdy_o <= rsp_rdy;

    store_misaligned_o <= store_i and address_misaligned; 
    load_misaligned_o  <= load_i  and address_misaligned;

end architecture rtl;
