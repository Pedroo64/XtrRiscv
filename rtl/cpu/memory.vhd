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
        siz_i     : in std_logic_vector(1 downto 0);
        dat_i     : in std_logic_vector(31 downto 0);
        rd_adr_i  : in std_logic_vector(4 downto 0);
        rd_adr_o  : out std_logic_vector(4 downto 0);
        rd_we_o   : out std_logic;
        rd_dat_o  : out std_logic_vector(31 downto 0);
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic;
        cmd_we_o  : out std_logic;
        cmd_siz_o : out std_logic_vector(1 downto 0);
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
    signal rd_we, d_rd_we   : std_logic;
    signal adr, d_adr : std_logic_vector(1 downto 0);
    signal siz, d_siz : std_logic_vector(1 downto 0);
    signal rd_adr : std_logic_vector(4 downto 0);
begin

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            cmd_vld <= '0';
            cmd_we_o  <= '0';
            rd_we     <= '0';
            d_rd_we <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                cmd_vld <= '0';
                cmd_we_o  <= '0';
                d_rd_we <= '0';
            else
                d_rd_we <= rd_we;
                d_siz   <= siz;
                d_adr   <= adr;
                rd_adr_o <= rd_adr;
                if en_i = '1' and vld_i = '1' and rdy = '1' then
                    cmd_vld   <= '1';
                    cmd_we_o  <= we_i;
                    cmd_adr_o <= adr_i;
                    rd_we     <= not we_i;
                    rd_adr  <= rd_adr_i;
                    cmd_siz_o <= siz_i;
                    siz       <= siz_i;
                    adr       <= adr_i(1 downto 0);
                    case siz_i is
                        when "00" =>
                            cmd_dat_o <= dat_i(7 downto 0) & dat_i(7 downto 0) & dat_i(7 downto 0) & dat_i(7 downto 0);
                        when "01" =>
                            cmd_dat_o <= dat_i(15 downto 0) & dat_i(15 downto 0);
                        when others =>
                            cmd_dat_o <= dat_i;
                    end case;
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
    rd_we_o <= d_rd_we and rsp_vld_i;
    process (d_siz, d_adr, rsp_dat_i)
    begin
        case d_siz is
            when "00" =>
                case d_adr is
                    when "00" =>
                        rd_dat_o <= x"000000" & rsp_dat_i(7 downto 0);
                    when "01" =>
                        rd_dat_o <= x"000000" & rsp_dat_i(15 downto 8);
                    when "10" =>
                        rd_dat_o <= x"000000" & rsp_dat_i(23 downto 16);
                    when "11" =>
                        rd_dat_o <= x"000000" & rsp_dat_i(31 downto 24);
                    when others =>
                end case;
            when "01" =>
                if d_adr(1) = '0' then
                    rd_dat_o <= x"0000" & rsp_dat_i(15 downto 0);
                else
                    rd_dat_o <= x"0000" & rsp_dat_i(31 downto 16);
                end if;
            when others =>
                rd_dat_o <= rsp_dat_i;
        end case;
    end process;

end architecture rtl;