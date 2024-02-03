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
        memory_addr_i : in std_logic_vector(1 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_dat_i : in std_logic_vector(31 downto 0);
        rd_we_i : in std_logic;
        rsp_dat_i : in std_logic_vector(31 downto 0);
        rsp_vld_i : in std_logic;
        muldiv_i : in std_logic;
        muldiv_result_i : in std_logic_vector(31 downto 0);
        muldiv_ready_i : in std_logic;
        valid_o : out std_logic;
        mem_read_o : out std_logic;
        mem_read_vld_o : out std_logic;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        ready_o : out std_logic;
        muldiv_o : out std_logic
    );
end entity writeback;

architecture rtl of writeback is
    signal valid : std_logic;
    signal funct3 : std_logic_vector(2 downto 0);
    signal rd_adr : std_logic_vector(4 downto 0);
    signal rd_dat : std_logic_vector(31 downto 0);
    signal rd_we : std_logic;
-- memory-read
    signal mem_read_vld : std_logic;
    signal mem_rsp_dat : std_logic_vector(31 downto 0);
    signal mem_read : std_logic;
    signal mem_sel : std_logic_vector(1 downto 0);
    signal mem_read_dat8 : std_logic_vector(7 downto 0);
    signal mem_read_dat16 : std_logic_vector(15 downto 0);
    signal mem_read_dat : std_logic_vector(31 downto 0);
-- muldiv
    signal muldiv : std_logic;
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
                rd_we <= rd_we_i;
                funct3 <= funct3_i;
                mem_read <= memory_read_i and rd_we_i;
                muldiv <= muldiv_i;
                mem_sel <= memory_addr_i;
            end if;
            rd_dat <= rd_dat_i;
            mem_rsp_dat <= rsp_dat_i;
            mem_read_vld <= rsp_vld_i;
        end if;
    end process;

    with mem_sel select
        mem_read_dat8 <= 
            mem_rsp_dat(7 downto 0)   when "00",
            mem_rsp_dat(15 downto 8)  when "01",
            mem_rsp_dat(23 downto 16) when "10",
            mem_rsp_dat(31 downto 24) when "11",
            (others => '-') when others;
    
    mem_read_dat16 <= 
        mem_rsp_dat(15 downto 0) when mem_sel(1) = '0' else
        mem_rsp_dat(31 downto 16);

    mem_read_dat <= 
        (8 to 31 => (not funct3(2) and mem_read_dat8(7))) & mem_read_dat8 when funct3(1 downto 0) = "00" else
        (16 to 31 => (not funct3(2) and mem_read_dat16(15))) & mem_read_dat16 when funct3(1 downto 0) = "01" else
        mem_rsp_dat;

    valid_o <= (valid and not muldiv) or (valid and muldiv and muldiv_ready_i);
    rd_adr_o <= rd_adr;
    rd_dat_o <= 
        muldiv_result_i when muldiv = '1' else
        mem_read_dat when mem_read = '1' else
        rd_dat;
    mem_read_o <= mem_read;
    mem_read_vld_o <= mem_read_vld;
    rd_we_o <= rd_we;

    process (valid, muldiv, muldiv_ready_i)
    begin
        if valid = '1' and muldiv = '1' then
            ready_o <= muldiv_ready_i;
        else
            ready_o <= '1';
        end if;
    end process;
    muldiv_o <= muldiv;
end architecture rtl;
