library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity debug_extension is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        halt_i : in std_logic;
        ebreak_i : in std_logic;
        dret_i : in std_logic;
        dcsr_i : in std_logic_vector(31 downto 0);
        exception_valid_o : out std_logic;
        exception_taken_i : in std_logic;
        cause_debug_o : out std_logic;
        debug_mode_o : out std_logic
    );
end entity debug_extension;

architecture rtl of debug_extension is
    type debug_st is (st_idle, st_halt, st_debug_mode);
    signal current_st : debug_st;
    signal exception_valid : std_logic;
    signal C_DCSR_EBREAKM : integer := 15;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            current_st <= st_idle;
        elsif rising_edge(clk_i) then
            case current_st is
                when st_idle =>
                    if halt_i = '1' or dcsr_i(2) = '1' then
                        current_st <= st_halt;
                    elsif ebreak_i = '1' and dcsr_i(C_DCSR_EBREAKM) = '1' then
                        current_st <= st_debug_mode;
                    end if;
                when st_halt =>
                    if exception_taken_i = '1' then
                        current_st <= st_debug_mode;
                    end if;
                when st_debug_mode =>
                    if dret_i = '1' then
                        current_st <= st_idle;
                    end if;
                when others =>
            end case;
        end if;
    end process;

    debug_mode_o <= 
        '1' when current_st = st_debug_mode else
        '0';

    exception_valid <= 
        '1' when current_st = st_halt else 
        '0';
    
    exception_valid_o <= exception_valid;

    cause_debug_o <= 
        '1' when current_st = st_halt and exception_taken_i = '1' else
        '1' when current_st = st_idle and dcsr_i(C_DCSR_EBREAKM) = '1' else
        '0';

end architecture rtl;