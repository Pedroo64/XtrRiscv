library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

use work.vhdl_utils.all;

entity tb_dcu is
end entity tb_dcu;

architecture rtl of tb_dcu is
    constant C_CLK_PER : time := 10 ns;
    constant C_MEMORY_WIDTH : integer := 32;
    constant C_MEMORY_DEPTH : integer := 4096;
    constant C_MEMORY_ADDR_WIDTH : integer := integer(ceil(log2(real(C_MEMORY_DEPTH))));
    type memory_t is array (0 to C_MEMORY_DEPTH - 1) of std_logic_vector(C_MEMORY_WIDTH - 1 downto 0);
    type fifo_t is array (0 to 15) of std_logic_vector(31 downto 0);
    signal arst, clk : std_logic := '0';
    -- CPU
    signal cpu_addr : std_logic_vector(31 downto 0);
    signal cpu_wdat, cpu_rdat : std_logic_vector(31 downto 0);
    signal cpu_cvld, cpu_wren : std_logic;
    signal cpu_crdy, cpu_rvld : std_logic;
    signal cpu_strb : std_logic_vector(3 downto 0);
    -- BIU
    signal biu_addr : std_logic_vector(31 downto 0);
    signal biu_wdat, biu_rdat : std_logic_vector(31 downto 0);
    signal biu_cvld, biu_wren : std_logic;
    signal biu_crdy, biu_rvld : std_logic;
    signal biu_strb : std_logic_vector(3 downto 0);
    -- Pending xfer
    signal fifo_q : fifo_t;
    signal fifo_we, fifo_re : std_logic;
    signal fifo_wptr_q, fifo_rptr_q : std_logic_vector(4 downto 0);
    signal fifo_wdat, fifo_rdat : std_logic_vector(31 downto 0);
    signal fifo_empty, fifo_full : std_logic;
    -- Debug signals
    signal expected_value_q : std_logic_vector(31 downto 0);
begin

    process
    begin
        arst <= '1'; wait for C_CLK_PER;
        arst <= '0'; wait;
    end process;

    process
    begin
        clk <= '0'; wait for C_CLK_PER / 2;
        clk <= '1'; wait for C_CLK_PER / 2;
    end process;

    -- Stimuli

    process (clk, arst)
        variable seed1, seed2 : positive;
        impure function random(N: in integer) return std_logic_vector is
            variable r : real;
            variable s : std_logic_vector(N-1 downto 0);
        begin
            for i in 0 to N - 1 loop
                uniform(seed1, seed2, r);
                if r <= 0.5 then
                    s(i) := '1';
                else
                    s(i) := '0';
                end if;
            end loop;
            return s;
        end function;
    begin
        if arst = '1' then
            cpu_addr <= (others => '0');
            cpu_wdat <= (others => '0');
            cpu_strb <= (others => '0');
            cpu_cvld <= '0';
            cpu_wren <= '0';
        elsif rising_edge(clk) then
            if cpu_crdy = '1' and fifo_full = '0' then
                cpu_addr <= (31 downto C_MEMORY_ADDR_WIDTH => '0') & std_logic_vector(random(C_MEMORY_ADDR_WIDTH - 2)) & "00";
                cpu_wdat <= std_logic_vector(random(32));
                cpu_strb <= std_logic_vector(random(4));
                cpu_wren <= std_logic(random(1)(0));
                cpu_cvld <= '1'; -- std_logic(random(1)(0));
            end if;
        end if;
    end process;

    -- DUT
    u_dcu : entity work.dcu
        generic map (
            G_CACHE_SIZE => 64
        )
        port map (
            arst_i => arst,
            clk_i => clk,
            cpu_adr_i => cpu_addr,
            cpu_dat_i => cpu_wdat,
            cpu_siz_i => cpu_strb,
            cpu_wr_i => cpu_wren,
            cpu_vld_i => cpu_cvld,
            cpu_rdy_o => cpu_crdy,
            cpu_dat_o => cpu_rdat,
            cpu_vld_o => cpu_rvld,
            biu_adr_o => biu_addr,
            biu_dat_o => biu_wdat,
            biu_wr_o => biu_wren,
            biu_vld_o => biu_cvld,
            biu_rdy_i => biu_crdy,
            biu_dat_i => biu_rdat,
            biu_vld_i => biu_rvld
        );

    -- FIFO
    fifo_we <= cpu_cvld and cpu_crdy and not cpu_wren;
    fifo_re <= cpu_rvld;

    fifo_wdat <= cpu_addr;

    process (clk, arst)
    begin
        if arst = '1' then
            fifo_wptr_q <= (others => '0');
            fifo_rptr_q <= (others => '0');
        elsif rising_edge(clk) then
            if fifo_we = '1' then
                fifo_wptr_q <= std_logic_vector(unsigned(fifo_wptr_q) + 1);
            end if;
            if fifo_re = '1' then
                fifo_rptr_q <= std_logic_vector(unsigned(fifo_rptr_q) + 1);
            end if;
        end if;
    end process;

    fifo_empty <= '1' when fifo_wptr_q = fifo_rptr_q else '0';
    fifo_full <= '1' when (fifo_wptr_q(fifo_wptr_q'left)              xor fifo_rptr_q(fifo_rptr_q'left)) = '1'
                      and (fifo_wptr_q(fifo_wptr_q'left - 1 downto 0)  =  fifo_rptr_q(fifo_rptr_q'left - 1 downto 0)) else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if fifo_we = '1' then
                fifo_q(to_integer(unsigned(fifo_wptr_q(fifo_wptr_q'left - 1 downto 0)))) <= fifo_wdat;
            end if;
        end if;
    end process;

    fifo_rdat <= fifo_q(to_integer(unsigned(fifo_rptr_q(fifo_rptr_q'left - 1 downto 0))));

    -- Memory
    process (clk)
        variable ref_mem, imp_mem : memory_t := (others => (others => '0'));
        -- procedure print_event (addr : in std_logic_vector; wr : in std_logic; strb : std_logic_vector) is
        --     variable s : string(1 to 128);
        --     variable w : character;
        --     variable d : std_logic_vector(31 downto 0);
        --     constant dots : string := "..";
        -- begin
        --     if wr = '1' then
        --         w := 'W';
        --         d := cpu_wdat;
        --     else
        --         w := 'R';
        --         d := ref_mem(to_integer(unsigned(cpu_addr)));
        --     end if;
        --     s := to_hex_str(addr) & ' ' & w & ' ';
        --     for i in strb'range loop
        --         if strb(i) = '1' then
        --             s := s & to_hex_str(d((i+1)*8-1 downto i*8));
        --         else
        --             s := s & dots;
        --         end if;
        --     end loop;
        --     report s;
        -- end procedure;
    begin
        if rising_edge(clk) then
            if cpu_rvld = '1' then
                expected_value_q <= ref_mem(to_integer(unsigned(fifo_rdat(C_MEMORY_ADDR_WIDTH+1 downto 2))));
            end if;
            if cpu_rvld = '1' and cpu_rdat /= ref_mem(to_integer(unsigned(fifo_rdat(C_MEMORY_ADDR_WIDTH+1 downto 2)))) then
                -- assert false report "Data missmatch:@" & to_hex_str(fifo_rdat) & " GOT " & to_hex_str(cpu_rdat) & " EXP " & to_hex_str(ref_mem(to_integer(unsigned(fifo_rdat(C_MEMORY_ADDR_WIDTH+1 downto 2))))) severity failure;
                vhdl_assert(true, "Data missmatch:@" & to_hex_str(fifo_rdat) & " GOT " & to_hex_str(cpu_rdat) & " EXP " & to_hex_str(ref_mem(to_integer(unsigned(fifo_rdat(C_MEMORY_ADDR_WIDTH+1 downto 2))))));
            end if;
            if cpu_cvld = '1' and cpu_wren = '1' and cpu_crdy = '1' then
                for i in cpu_strb'range loop
                    if cpu_strb(i) = '1' then
                        ref_mem(to_integer(unsigned(cpu_addr(C_MEMORY_ADDR_WIDTH+1 downto 2))))((i+1)*8-1 downto i*8) := cpu_wdat((i+1)*8-1 downto i*8);
                    end if;
                end loop;
            end if;
            if biu_cvld = '1' and biu_wren = '1' and biu_crdy = '1' then
                for i in biu_strb'range loop
                    imp_mem(to_integer(unsigned(biu_addr(C_MEMORY_ADDR_WIDTH+1 downto 2))))((i+1)*8-1 downto i*8) := biu_wdat((i+1)*8-1 downto i*8);
                end loop;
            end if;
            if biu_cvld = '1' and biu_wren = '0' and biu_crdy = '1' then
                biu_rdat <= imp_mem(to_integer(unsigned(biu_addr(C_MEMORY_ADDR_WIDTH+1 downto 2))));
            else
                biu_rdat <= (others => '-');
            end if;

        end if;
    end process;
    biu_strb <= (others => '1');
    biu_crdy <= '1';

    process (clk)
    begin
        if rising_edge(clk) then
            if biu_cvld = '1' and biu_wren = '0' and biu_crdy = '1' then
                biu_rvld <= '1';
            else
                biu_rvld <= '0';
            end if;
        end if;
    end process;

end architecture rtl;