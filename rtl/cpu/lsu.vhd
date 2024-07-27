library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity lsu is
    generic (
        G_TWO_CYCLES_READ : boolean := FALSE
    );
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
begin
    
    gen_one_cycle_read: if G_TWO_CYCLES_READ = FALSE generate
    begin
    
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
    end generate gen_one_cycle_read;


end architecture rtl;