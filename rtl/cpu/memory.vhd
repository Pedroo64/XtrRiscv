library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity memory is
    port (
        arst_i    : in std_logic;
        clk_i     : in std_logic;
        srst_i    : in std_logic;
        en_i      : in std_logic;
        adr_i     : in std_logic_vector(31 downto 0);
        vld_i     : in std_logic;
        we_i      : in std_logic;
        dat_i     : in std_logic_vector(31 downto 0);
        rd_adr_i  : in std_logic_vector(4 downto 0);
        rd_adr_o  : out std_logic_vector(4 downto 0);
        rd_we_o   : out std_logic;
        rd_dat_o  : out std_logic_vector(31 downto 0);
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic;
        cmd_we_o  : out std_logic;
        cmd_dat_o : out std_logic_vector(31 downto 0);
        cmd_rdy_i : in std_logic;
        rsp_vld_i : in std_logic;
        rsp_dat_i : in std_logic_vector(31 downto 0);
        rdy_o     : out std_logic
    );
end entity memory;

architecture rtl of memory is
    signal rdy     : std_logic;
    signal cmd_vld : std_logic;
    signal rd_we   : std_logic;
begin

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            cmd_vld <= '0';
            cmd_we_o  <= '0';
            rd_we     <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                cmd_vld <= '0';
                cmd_we_o  <= '0';
            else
                if en_i = '1' and vld_i = '1' and rdy = '1' then
                    cmd_vld   <= '1';
                    cmd_we_o  <= we_i;
                    cmd_adr_o <= adr_i;
                    cmd_dat_o <= dat_i;
                    rd_we     <= not we_i;
                    rd_adr_o  <= rd_adr_i;
                elsif cmd_vld = '1' and cmd_rdy_i = '1' then
                    cmd_vld <= '0';
                    rd_we   <= '0';
                end if;
            end if;
        end if;
    end process;

    cmd_vld_o <= cmd_vld;

    rdy <=
        '0' when cmd_vld = '1' and cmd_rdy_i = '0' else
        en_i;
    rdy_o   <= rdy;
    rd_we_o <= rd_we and rsp_vld_i;
    rd_dat_o <= rsp_dat_i;
end architecture rtl;