library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity instruction_fecth is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        load_pc_i : in std_logic;
        pc_i : in std_logic_vector(31 downto 0);
        cmd_adr_o : out std_logic_vector(31 downto 0);
        cmd_vld_o : out std_logic; 
        rsp_dat_i : in std_logic_vector(31 downto 0);
        cmd_rdy_i : in std_logic;
        rsp_vld_i : in std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        instr_o : out std_logic_vector(31 downto 0);
        instr_vld_o : out std_logic;
        decode_rdy_i : in std_logic
    );
end entity instruction_fecth;

architecture rtl of instruction_fecth is
    signal pc : unsigned(31 downto 0);
    signal instr_dat_hold : std_logic_vector(31 downto 0);
    signal cmd_vld : std_logic;
    signal d_decode_rdy : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            pc <= (others => '0');
            cmd_vld <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                pc <= (others => '0');
                cmd_vld <= '0';
            else
                cmd_vld <= '0';
                if en_i = '1' then
                    cmd_vld <= '1';
                    if load_pc_i = '1' then
                        pc <= unsigned(pc_i);
                    elsif cmd_vld = '1' and cmd_rdy_i = '1' and decode_rdy_i = '1' then
                        pc <= pc + 4;
                    end if;
                end if;
--                if true then
--                    if load_pc_i = '1' then
--                        pc <= unsigned(pc_i);
--                    elsif en_i = '1' and cmd_rdy_i = '1' and decode_rdy_i = '1' then
--                        pc <= pc + 4;
--                    end if;
--                end if;
            end if;
        end if;
    end process;
    
    cmd_adr_o <= std_logic_vector(pc);
    cmd_vld_o <= 
        '1' when decode_rdy_i = '1' and cmd_vld = '1' else
        '0';
--    cmd_vld_o <= 
--        '1' when en_i = '1' and decode_rdy_i = '1' else 
--        '0';
    
    instr_o <= 
        instr_dat_hold when decode_rdy_i = '1' and d_decode_rdy = '0' else
        rsp_dat_i;
    instr_vld_o <= 
        '1' when decode_rdy_i = '1' and d_decode_rdy = '0' else
        rsp_vld_i;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if decode_rdy_i = '1' then
                pc_o <= std_logic_vector(pc);
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rsp_vld_i = '1' then
                instr_dat_hold <= rsp_dat_i;
            end if;
        end if;
    end process;

--    process (clk_i, arst_i)
--    begin
--        if arst_i = '1' then
--            instr_vld_o <= '0';
--        elsif rising_edge(clk_i) then
--            if decode_rdy_i = '1' then
--                instr_vld_o <= rsp_vld_i;
--                instr_o <= rsp_dat_i;
--                pc_o <= std_logic_vector(pc);
--            end if;
--        end if;
--    end process;
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            d_decode_rdy <= decode_rdy_i;
        end if;
    end process;
end architecture rtl;