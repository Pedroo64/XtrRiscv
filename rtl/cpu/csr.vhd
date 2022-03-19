library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity csr is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        we_i : in std_logic;
        vld_i : in std_logic;
        adr_i : in std_logic_vector(11 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        dat_i : in std_logic_vector(31 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        wb_rdy_i : in std_logic;
        rdy_o : out std_logic
    );
end entity csr;

architecture rtl of csr is
    function write_csr (csr_dat : std_logic_vector(31 downto 0); current_csr : std_logic_vector(31 downto 0); funct3 : std_logic_vector(2 downto 0)) return std_logic_vector is
        variable ret : std_logic_vector(31 downto 0);
    begin
        case funct3(1 downto 0) is
            when "01" =>
                ret := csr_dat;
            when "10" =>
                ret := current_csr or csr_dat;
            when others =>
                ret := current_csr and csr_dat;
        end case;
        return ret;
    end function;
    signal rdy, rd_we : std_logic;
    signal value : std_logic_vector(31 downto 0) := (others => '0');
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            rd_we <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                rd_we <= '0';
            else
                if en_i = '1' and vld_i = '1' and rdy = '1' then
                    rd_we <= '1';
                    rd_dat_o <= value;
                    rd_adr_o <= rd_adr_i;
                    if we_i = '1' then
                        value <= write_csr(dat_i, value, funct3_i);
                    end if;
                elsif rd_we = '1' and wb_rdy_i = '1' then
                    rd_we <= '0';
                end if;
            end if;
        end if;
    end process;

    rdy <= '0' when rd_we = '1' and wb_rdy_i = '0' else '1';

    rd_we_o <= rd_we;
    rdy_o <= rdy;
    
end architecture rtl;