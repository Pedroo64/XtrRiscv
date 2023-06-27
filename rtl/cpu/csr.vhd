library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.csr_def.all;

entity csr is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        enable_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        address_i : in std_logic_vector(11 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        data_o : out std_logic_vector(31 downto 0);
        exception_pc_i : in std_logic_vector(31 downto 0);
        exception_taken_i : in std_logic;
        exception_exit_i : in std_logic;
        ecall_i : in std_logic;
        ebreak_i : in std_logic;
        cause_external_irq_i : in std_logic;
        cause_timer_irq_i : in std_logic;
        mstatus_o : out std_logic_vector(31 downto 0);
        mie_o : out std_logic_vector(31 downto 0);
        mtvec_o : out std_logic_vector(31 downto 0);
        mepc_o : out std_logic_vector(31 downto 0)
    );
end entity csr;

architecture rtl of csr is
    signal we : std_logic;
    signal csr_write, csr_read : std_logic_vector(31 downto 0);
    signal mscratch : std_logic_vector(31 downto 0) := (others => '0');
    signal mstatus : std_logic_vector(31 downto 0) := (others => '0');
    signal mie : std_logic_vector(31 downto 0) := (others => '0');
    signal mtvec : std_logic_vector(31 downto 0) := (others => '0');
    signal mepc : std_logic_vector(31 downto 0) := (others => '0');
    signal mcause : std_logic_vector(31 downto 0) := (others => '0');
    signal mtval : std_logic_vector(31 downto 0) := (others => '0');
begin
    we <= enable_i;

    with address_i select
        csr_read <= 
            mscratch        when CSR_MSCRATCH,
            mie             when CSR_MSTATUS,
            mstatus         when CSR_MIE,
            mtvec           when CSR_MTVEC,
            mepc            when CSR_MEPC,
            mcause          when CSR_MCAUSE,
            mtval           when CSR_MTVAL,
            (others => '0') when others;

    block_alu : block
        signal alu_a, alu_b, alu_y : std_logic_vector(31 downto 0);
    begin
        alu_a <= data_i;
        alu_b <= csr_read;
        with funct3_i(1 downto 0) select
            alu_y <= 
                alu_a or alu_b when "10",
                alu_a and (not alu_b) when "11",
                alu_a when others;
        csr_write <= alu_y;
    end block;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            data_o <= csr_read;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if address_i = CSR_MSCRATCH and we = '1' then
                mscratch <= csr_write;
            end if;
        end if;
    end process;
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mtvec <= (others => '0');
            mie <= (others => '0');
        elsif rising_edge(clk_i) then
            if address_i = CSR_MTVEC and we = '1' then
                mtvec <= csr_write;
            end if;
            if address_i = CSR_MIE and we = '1' then
                mie <= csr_write;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if exception_taken_i = '1' then
                if ecall_i = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_ECALL;
                elsif ebreak_i = '1' then
                    mcause <= CSR_MCAUSE_BREAKPOINT;
                elsif cause_external_irq_i = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT;
                elsif cause_timer_irq_i = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_TIMER_INTERRUPT;
                end if;
            elsif address_i = CSR_MCAUSE and we = '1' then
                mcause <= csr_write;
            end if;
            if exception_taken_i = '1' then
                mepc <= exception_pc_i;
            elsif address_i = CSR_MEPC and we = '1' then
                mepc <= csr_write;
            end if;
            if exception_taken_i = '1' and ebreak_i = '1' then
                mtval <= exception_pc_i;
            elsif address_i = CSR_MTVAL and we = '1' then
                mtval <= csr_write;
            end if;

        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mstatus <= (others => '0');
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mstatus <= (others => '0');
            else
                if exception_taken_i = '1' then
                    mstatus(7) <= mstatus(3);
                    -- mstatus.mie = 0
                    mstatus(3) <= '0';
                    -- mstatus.mpp = current privilege mode 
                    mstatus(12 downto 11) <= "11";
                elsif exception_exit_i = '1' then
                    -- privilege set to mstatus.mpp
                    -- mstatus.mie = mstatus.mpie
                    mstatus(3) <= mstatus(7);
                    mstatus(7) <= '1';
                    mstatus(12 downto 11) <= "11";
                elsif address_i = CSR_MSTATUS and we = '1' then
                    mstatus <= csr_write;
                end if;
            end if;
        end if;
    end process;

    mstatus_o <= mstatus;
    mie_o <= mie;
    mtvec_o <= mtvec;
    mepc_o <= mepc;
    
    
end architecture rtl;