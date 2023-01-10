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
    type fetch_st_t is (st_idle, st_halt, st_fetch);
    signal current_st, next_st : fetch_st_t;
    signal pc : unsigned(31 downto 0);
    signal cmd_vld : std_logic;
begin
    
    process (current_st, en_i, decode_rdy_i)
    begin
        case current_st is
            when st_idle =>
                if en_i = '1' then
                    if decode_rdy_i = '1' then
                        next_st <= st_fetch;
                    else
                        next_st <= st_halt;
                    end if;
                else
                    next_st <= st_idle;
                end if;
            when st_halt =>
                if en_i = '0' then
                    next_st <= st_idle;
                elsif decode_rdy_i = '1' then
                    next_st <= st_fetch;
                else
                    next_st <= st_halt;
                end if;
            when st_fetch =>
                if en_i = '0' then
                    next_st <= st_idle;
                elsif decode_rdy_i = '0' then
                    next_st <= st_halt;
                else
                    next_st <= st_fetch;
                end if;
            when others =>
                next_st <= st_idle;
        end case;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            current_st <= st_idle;
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                current_st <= st_idle;
            else
                current_st <= next_st;
            end if;
        end if;
    end process;

    cmd_vld <= 
        '1' when current_st = st_fetch and decode_rdy_i = '1' else
        '1' when current_st = st_halt and decode_rdy_i = '1' else
        '0';

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            pc <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                pc <= (others => '0');
            else
                if load_pc_i = '1' then
                    pc <= unsigned(pc_i);
                elsif cmd_vld = '1' and cmd_rdy_i = '1' then
                    pc <= pc + 4;
                end if;
            end if;
        end if;
    end process;
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if cmd_vld = '1' then
                pc_o <= std_logic_vector(pc);
            end if;
        end if;
    end process;

    cmd_adr_o <= std_logic_vector(pc);
    cmd_vld_o <= cmd_vld;
    
    instr_o <= rsp_dat_i;
    instr_vld_o <=
        '1' when current_st = st_halt and decode_rdy_i = '1' else 
        rsp_vld_i;

end architecture rtl;