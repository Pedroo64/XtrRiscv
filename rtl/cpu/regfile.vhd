library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity regfile is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs1_dat_o : out std_logic_vector(31 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        rs2_dat_o : out std_logic_vector(31 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        rd_dat_i : in std_logic_vector(31 downto 0)
    );
end entity regfile;

architecture rtl of regfile is
    type regfile_t is array (natural range <>) of std_logic_vector(31 downto 0);
    signal reg : regfile_t(0 to 31) := (others => (others => '0'));
    signal we : std_logic;
begin

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if we = '1' then
                reg(to_integer(unsigned(rd_adr_i))) <= rd_dat_i;
            end if;
            rs1_dat_o <= reg(to_integer(unsigned(rs1_adr_i)));
            rs2_dat_o <= reg(to_integer(unsigned(rs2_adr_i)));
        end if;
    end process;

    we <= '0' when unsigned(rd_adr_i) = 0 else rd_we_i;

end architecture rtl;