library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.csr_def.all;
use work.rv32i_pkg.all;

entity csr is
    generic (
        G_ECALL : boolean := FALSE;
        G_EBREAK : boolean := FALSE;
        G_INTERRUPTS : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        execute_en_i : in std_logic;
        execute_valid_i : in std_logic;
        execute_opcode_i : in opcode_t;
        execute_immediate_i : in std_logic_vector(31 downto 0);
        execute_funct3_i : in std_logic_vector(2 downto 0);
        execute_current_pc_i : in std_logic_vector(31 downto 0);
        execute_rs1_dat_i : in std_logic_vector(31 downto 0);
        execute_zimm_i : in std_logic_vector(4 downto 0);
        memory_en_i : in std_logic;
        memory_valid_i : in std_logic;
        memory_funct3_i : in std_logic_vector(2 downto 0);
        memory_target_pc_i : in std_logic_vector(31 downto 0);
        memory_branch_i : in std_logic;
        read_data_o : out std_logic_vector(31 downto 0);
        target_pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        external_interrupt_i : in std_logic;
        timer_interrupt_i : in std_logic
    );
end entity csr;

architecture rtl of csr is
    constant C_XRET : boolean := G_ECALL or G_EBREAK or G_INTERRUPTS;
-- execute stage
    signal execute_ecall, execute_ebreak, execute_mret : std_logic;
-- memory stage
    signal memory_ecall, memory_ebreak, memory_mret : std_logic;
    signal memory_pc : std_logic_vector(31 downto 0);
-- csr
    signal async_exception_en, async_exception : std_logic;
    signal external_interrupt_en, timer_interrupt_en : std_logic;
    signal exception_pc : std_logic_vector(31 downto 0);
    signal exception_taken, exception_exit : std_logic;
    signal we : std_logic;
    signal write_enable : std_logic;
    signal write_address, read_address : std_logic_vector(11 downto 0);
    signal write_data, read_data : std_logic_vector(31 downto 0);
    signal csr_write_addr, csr_read_addr : std_logic_vector(11 downto 0);
    signal csr_write_data, csr_read_data : std_logic_vector(31 downto 0);
    signal ecall, ebreak : std_logic;
    signal xret, mret : std_logic;
    signal mscratch : std_logic_vector(31 downto 0) := (others => '0');
    signal mstatus : std_logic_vector(31 downto 0) := (others => '0');
    signal mie : std_logic_vector(31 downto 0) := (others => '0');
    signal mtvec : std_logic_vector(31 downto 0) := (others => '0');
    signal mepc : std_logic_vector(31 downto 0) := (others => '0');
    signal mcause : std_logic_vector(31 downto 0) := (others => '0');
    signal mtval : std_logic_vector(31 downto 0) := (others => '0');
begin
-- Exception handling
    execute_ecall <= '1' when execute_opcode_i.sys = '1' and execute_funct3_i = RV32I_FN3_TRAP and execute_immediate_i(1 downto 0) = "00" and G_ECALL = TRUE else '0';
    execute_ebreak <= '1' when execute_opcode_i.sys = '1' and execute_funct3_i = RV32I_FN3_TRAP and execute_immediate_i(1 downto 0) = "01" and G_EBREAK = TRUE else '0';
    execute_mret <= '1' when execute_opcode_i.sys = '1' and execute_funct3_i = RV32I_FN3_TRAP and execute_immediate_i(1 downto 0) = "10" and C_XRET = TRUE else '0';
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_en_i = '1' then
                memory_ecall <= execute_ecall;
                memory_ebreak <= execute_ebreak;
                memory_mret <= execute_mret;
                memory_pc <= execute_current_pc_i;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if C_XRET = TRUE then
                async_exception <= ((external_interrupt_i and external_interrupt_en) or (timer_interrupt_i and timer_interrupt_en));
            else
                async_exception <= '0';
            end if;
        end if;
    end process;

    async_exception_en <= mstatus(CSR_MSTATUS_MIE);
    external_interrupt_en <= mie(CSR_MIE_MEIE);
    timer_interrupt_en <= mie(CSR_MIE_MTIE);

    ecall <= memory_ecall;
    ebreak <= memory_ebreak;
    mret <= memory_mret;
    xret <= mret;

    exception_taken <= ((ecall or ebreak) and memory_valid_i) or (async_exception and async_exception_en);
    exception_exit <= mret and memory_valid_i;

    process (ecall, ebreak, memory_pc, async_exception_en, memory_branch_i, memory_target_pc_i, execute_current_pc_i)
    begin
        if (ecall or ebreak) = '1' then
            exception_pc <= memory_pc;
        elsif async_exception_en = '1' then
            if memory_branch_i = '1' then
                exception_pc <= memory_target_pc_i;
            else
                exception_pc <= execute_current_pc_i;
            end if;
        else
            exception_pc <= (others => '-');
        end if;
    end process;

    target_pc_o <= 
        mtvec when (ecall or ebreak or async_exception) = '1' else
        mepc when xret = '1' else
        (others => '-');

    load_pc_o <= ecall or ebreak or xret or (async_exception and async_exception_en);

    read_data_o <= read_data;

-- CSR
    we <= write_enable and memory_valid_i;
    csr_read_addr <= execute_immediate_i(11 downto 0);
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_en_i = '1' then
                csr_write_addr <= csr_read_addr;
                read_data <= csr_read_data;
                if execute_opcode_i.sys = '1' and execute_funct3_i /= RV32I_FN3_TRAP then
                    write_enable <= '1';
                else
                    write_enable <= '0';
                end if;
                if execute_funct3_i(2) = '1' then
                    write_data <= (31 downto 5 => '0') & execute_zimm_i;
                else
                    write_data <= execute_rs1_dat_i;
                end if;
            end if;
        end if;
    end process;

    with csr_read_addr select
        csr_read_data <= 
            mscratch        when CSR_MSCRATCH,
            mie             when CSR_MSTATUS,
            mstatus         when CSR_MIE,
            mtvec           when CSR_MTVEC,
            mepc            when CSR_MEPC,
            mcause          when CSR_MCAUSE,
            mtval           when CSR_MTVAL,
            (others => '0') when others;

    with memory_funct3_i(1 downto 0) select
        csr_write_data <= 
            write_data or read_data when "10",
            write_data and (not read_data) when "11",
            write_data when others;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if csr_write_addr = CSR_MSCRATCH and we = '1' then
                mscratch <= csr_write_data;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mtvec <= (others => '0');
            mie <= (others => '0');
        elsif rising_edge(clk_i) then
            if csr_write_addr = CSR_MTVEC and we = '1' then
                mtvec <= csr_write_data;
            end if;
            if csr_write_addr = CSR_MIE and we = '1' then
                mie <= csr_write_data;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if exception_taken = '1' then
                if ecall = '1' then
                    mcause <= CSR_MCAUSE_MACHINE_ECALL;
                elsif ebreak = '1' then
                    mcause <= CSR_MCAUSE_BREAKPOINT;
--                elsif cause_external_irq_i = '1' then
--                    mcause <= CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT;
--                elsif cause_timer_irq_i = '1' then
--                    mcause <= CSR_MCAUSE_MACHINE_TIMER_INTERRUPT;
                end if;
            elsif csr_write_addr = CSR_MCAUSE and we = '1' then
                mcause <= csr_write_data;
            end if;
            if exception_taken = '1' then
                mepc <= exception_pc;
            elsif csr_write_addr = CSR_MEPC and we = '1' then
                mepc <= csr_write_data;
            end if;
            if exception_taken = '1' and ebreak = '1' then
                mtval <= exception_pc;
            elsif csr_write_addr = CSR_MTVAL and we = '1' then
                mtval <= csr_write_data;
            end if;

        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mstatus <= (others => '0');
        elsif rising_edge(clk_i) then
            if exception_taken = '1' then
                mstatus(7) <= mstatus(3);
                -- mstatus.mie = 0
                mstatus(3) <= '0';
                -- mstatus.mpp = current privilege mode 
                mstatus(12 downto 11) <= "11";
            elsif exception_exit = '1' then
                -- privilege set to mstatus.mpp
                -- mstatus.mie = mstatus.mpie
                mstatus(3) <= mstatus(7);
                mstatus(7) <= '1';
                mstatus(12 downto 11) <= "11";
            elsif csr_write_addr = CSR_MSTATUS and we = '1' then
                mstatus <= csr_write_data;
            end if;
        end if;
    end process;


end architecture rtl;