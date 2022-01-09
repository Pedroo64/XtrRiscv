library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

entity bram is
    generic (
        C_DEPTH : integer := 256;
        C_ADDR_A_WIDTH : integer := 8;
        C_DATA_A_WIDTH : integer := 32;
        C_BYTE_A_WIDTH : integer := 8;
        C_ADDR_B_WIDTH : integer := 8;
        C_DATA_B_WIDTH : integer := 32;
        C_BYTE_B_WIDTH : integer := 8;
        C_INIT_FILE : string := "none"
    );
    port (
        arst_i : in std_logic := '0';
        clk_i : in std_logic;
        srst_i : in std_logic := '0';
        addr_a_i : in std_logic_vector(C_ADDR_A_WIDTH - 1 downto 0);
        en_a_i : in std_logic;
        we_a_i : in std_logic;
        be_a_i : in std_logic_vector((C_DATA_A_WIDTH / C_BYTE_A_WIDTH) - 1 downto 0);
        dat_a_i : in std_logic_vector(C_DATA_A_WIDTH - 1 downto 0);
        dat_a_o : out std_logic_vector(C_DATA_A_WIDTH - 1 downto 0);
        addr_b_i : in std_logic_vector(C_ADDR_B_WIDTH - 1 downto 0);
        en_b_i : in std_logic;
        we_b_i : in std_logic;
        be_b_i : in std_logic_vector((C_DATA_B_WIDTH / C_BYTE_B_WIDTH) - 1 downto 0);
        dat_b_i : in std_logic_vector(C_DATA_B_WIDTH - 1 downto 0);
        dat_b_o : out std_logic_vector(C_DATA_B_WIDTH - 1 downto 0)
    );
end entity bram;

architecture rtl of bram is
    constant C_NB_COL_A : integer := (C_DATA_A_WIDTH / C_BYTE_A_WIDTH);
    constant C_NB_COL_B : integer := (C_DATA_B_WIDTH / C_BYTE_B_WIDTH);
    type ram_t is array (0 to C_DEPTH - 1) of std_logic_vector(C_DATA_A_WIDTH - 1 downto 0);
    impure function ocram_ReadMemFile(FileName : STRING) return ram_t is
        file FileHandle       : TEXT;
        variable CurrentLine  : LINE;
        variable TempWord     : STD_LOGIC_VECTOR(31 downto 0);
        variable Result       : ram_t    := (others => (others => '0'));
    begin
        if FileName /= "none" then
            file_open(FileHandle, FileName,  read_mode);
            for i in 0 to Result'length - 1 loop
                exit when endfile(FileHandle);
                readline(FileHandle, CurrentLine);
                hread(CurrentLine, TempWord);
                Result(i)    := TempWord;
            end loop;
        end if;
        return Result;
    end function;
    signal ram : ram_t := ocram_ReadMemFile(C_INIT_FILE);
begin
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if en_a_i = '1' then
                if we_a_i = '1' then
                    for i in 0 to C_NB_COL_A - 1 loop
                        if be_a_i(i) = '1' then
                            ram(to_integer(unsigned(addr_a_i)))(i*8 + 7 downto i*8) <= dat_a_i(i*8 + 7 downto i*8);
                        end if;
                    end loop;
                end if;
                dat_a_o <= ram(to_integer(unsigned(addr_a_i)));
            end if;
            if en_b_i = '1' then
                if we_b_i = '1' then
                    for i in 0 to C_NB_COL_A - 1 loop
                        if be_b_i(i) = '1' then
                            ram(to_integer(unsigned(addr_b_i)))(i*8 + 7 downto i*8) <= dat_b_i(i*8 + 7 downto i*8);
                        end if;
                    end loop;
                end if;
                dat_b_o <= ram(to_integer(unsigned(addr_b_i)));
            end if;
        end if;
    end process;
    
end architecture rtl;