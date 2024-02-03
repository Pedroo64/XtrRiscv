library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lsu is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        valid_i : in std_logic;
        flush_i : in std_logic;
        address_i : in std_logic_vector(31 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        load_i : in std_logic;
        store_i : in std_logic;
        size_i : in std_logic_vector(1 downto 0);
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
        rsp_rdy_o : out std_logic
    );
end entity lsu;

architecture rtl of lsu is
    signal cmd_vld : std_logic;
    signal load : std_logic;
    signal cmd_rdy, rsp_rdy : std_logic;
begin
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            load <= '0';
        elsif rising_edge(clk_i) then
            if rsp_rdy = '1' then
                load <= valid_i and load_i and not flush_i;
            end if;
        end if;
    end process;

    cmd_vld <= valid_i and not flush_i;
    cmd_rdy <= '0' when cmd_vld = '1' and cmd_rdy_i = '0' else '1';
    rsp_rdy <= '0' when load = '1' and rsp_vld_i = '0' else '1';

    cmd_rdy_o <= cmd_rdy;
    rsp_rdy_o <= rsp_rdy;

    -- bus interface
    cmd_adr_o <= address_i;
    cmd_dat_o <= data_i;
    cmd_siz_o <= size_i;
    cmd_vld_o <= cmd_vld;
    cmd_we_o <= store_i;
    data_o <= rsp_dat_i;

end architecture rtl;