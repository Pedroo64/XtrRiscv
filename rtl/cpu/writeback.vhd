library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity writeback is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        flush_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        memory_read_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_dat_i : in std_logic_vector(31 downto 0);
        rd_we_i : in std_logic;
        rsp_dat_i : in std_logic_vector(31 downto 0);
        rsp_vld_i : in std_logic;
        valid_o : out std_logic;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        ready_o : out std_logic
    );
end entity writeback;

architecture rtl of writeback is
    signal valid : std_logic;
    signal funct3 : std_logic_vector(2 downto 0);
    signal rd_adr : std_logic_vector(4 downto 0);
    signal rd_dat : std_logic_vector(31 downto 0);
    signal rd_we : std_logic;
-- memory-read
    signal mem_read : std_logic;
    signal mem_sel : std_logic_vector(1 downto 0);
    signal mem_read_dat8 : std_logic_vector(7 downto 0);
    signal mem_read_dat16 : std_logic_vector(15 downto 0);
    signal mem_read_dat : std_logic_vector(31 downto 0);
begin
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            valid <= '0';
        elsif rising_edge(clk_i) then
            if enable_i = '1' then
                if flush_i = '1' then
                    valid <= '0';
                else
                    valid <= valid_i;
                end if;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' then
                rd_adr <= rd_adr_i;
                rd_dat <= rd_dat_i;
                rd_we <= rd_we_i;
                funct3 <= funct3_i;
                mem_read <= memory_read_i;
            end if;
        end if;
    end process;

    mem_sel <= rd_dat(1 downto 0);

    with mem_sel select
        mem_read_dat8 <= 
            rsp_dat_i(7 downto 0)   when "00",
            rsp_dat_i(15 downto 8)  when "01",
            rsp_dat_i(23 downto 16) when "10",
            rsp_dat_i(31 downto 24) when "11",
            (others => '-') when others;
    
    mem_read_dat16 <= 
        rsp_dat_i(15 downto 0) when mem_sel(1) = '0' else
        rsp_dat_i(31 downto 16);

    mem_read_dat <= 
        (8 to 31 => (not funct3(2) and mem_read_dat8(7))) & mem_read_dat8 when funct3(1 downto 0) = "00" else
        (16 to 31 => (not funct3(2) and mem_read_dat16(15))) & mem_read_dat16 when funct3(1 downto 0) = "01" else
        rsp_dat_i;

    valid_o <= valid;
    rd_adr_o <= rd_adr;
    rd_dat_o <= 
        mem_read_dat when mem_read = '1' else
        rd_dat;
    rd_we_o <= enable_i and valid and rd_we;
--    ready_o <= not (valid and not memory_read_i);
    process (valid, mem_read, rsp_vld_i)
    begin
        if valid = '1' and mem_read = '1' then
            ready_o <= rsp_vld_i;
        else
            ready_o <= '1';
        end if;
    end process;
end architecture rtl;