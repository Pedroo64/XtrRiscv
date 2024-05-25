library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.csr_def.all;
use work.rv32i_pkg.all;

entity csr is
    generic (
        G_ECALL : boolean := TRUE;
        G_EBREAK : boolean := TRUE;
        G_INTERRUPTS : boolean := TRUE;
        G_INSTRUCTION_MISALIGNED : boolean := TRUE;
        G_LOAD_MISALIGNED : boolean := TRUE;
        G_STORE_MISALIGNED : boolean := TRUE;
        G_EXTENSION_C : boolean := FALSE
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
        execute_ecall_i : in std_logic;
        execute_ebreak_i : in std_logic;
        execute_mret_i : in std_logic;
        execute_dret_i : in std_logic;
        memory_en_i : in std_logic;
        memory_valid_i : in std_logic;
        memory_opcode_i : in opcode_t;
        memory_address_i : in std_logic_vector(31 downto 0);
        memory_funct3_i : in std_logic_vector(2 downto 0);
        memory_target_pc_i : in std_logic_vector(31 downto 0);
        memory_branch_i : in std_logic;
        read_data_o : out std_logic_vector(31 downto 0);
        target_pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        external_interrupt_i : in std_logic;
        timer_interrupt_i : in std_logic;
        exception_entry_o : out std_logic;
        exception_exit_o : out std_logic;
        exception_sync_o : out std_logic;
        exception_async_o : out std_logic;
        mtvec_o : out std_logic_vector(31 downto 0);
        mepc_o : out std_logic_vector(31 downto 0);
        misaligned_load_o : out std_logic;
        misaligned_store_o : out std_logic;
        debug_cmd_adr_i : in std_logic_vector(7 downto 0);
        debug_cmd_dat_i : in std_logic_vector(31 downto 0);
        debug_cmd_vld_i : in std_logic;
        debug_cmd_we_i : in std_logic;
        debug_cmd_rdy_o : out std_logic;
        debug_rsp_dat_o : out std_logic_vector(31 downto 0);
        debug_rsp_vld_o : out std_logic;
        instr_valid_o : out std_logic;
        instr_data_o : out std_logic_vector(31 downto 0);
        fetch_enable_i : in std_logic;
        debug_mode_o : out std_logic;
        debug_reset_o : out std_logic
    );
end entity csr;

architecture rtl of csr is
constant C_XRET : boolean := G_ECALL or G_EBREAK or G_INTERRUPTS;
constant C_INSTRUCTION_MISALIGNED : boolean := G_INSTRUCTION_MISALIGNED;
constant C_LOAD_MISALIGNED : boolean := G_LOAD_MISALIGNED;
constant C_STORE_MISALIGNED : boolean := G_STORE_MISALIGNED;
-- Execute stage
signal execute_pc_valid : std_logic;
signal execute_ecall, execute_ebreak, execute_mret, execute_branch : std_logic;
signal execute_misaligned_load, execute_misaligned_store : std_logic;
-- Memory stage
signal memory_branch : std_logic;
signal memory_pc : std_logic_vector(31 downto 0);
signal memory_ecall, memory_ebreak, memory_mret : std_logic;
signal memory_misaligned_load, memory_misaligned_store : std_logic;
-- CSR logic
signal async_exception_pending : std_logic;
signal nxt_epc : std_logic_vector(31 downto 0);
signal epc_sel : std_logic;
signal instruction_address_misaligned, store_address_misaligned, load_address_misaligned, load_store_address_misaligned : std_logic;
signal async_exception, async_exception_en : std_logic;
signal timer_interrupt, timer_interrupt_en : std_logic;
signal external_interrupt, external_interrupt_en : std_logic;
signal exception_sync, exception_async : std_logic;
signal exception_entry, exception_exit : std_logic;
signal ecall, ebreak, mret : std_logic;
signal write_data, read_data : std_logic_vector(31 downto 0);
signal csr_write_address, csr_read_address : std_logic_vector(11 downto 0);
signal csr_write_data, csr_read_data : std_logic_vector(31 downto 0);
signal csr_write_enable, csr_read_enable : std_logic;
signal csr_machine_we, csr_machine_re : std_logic;
-- debug csr
signal execute_dret, memory_dret : std_logic;
signal debug_reset, debug_halt, debug_mode, dcsr_step, dret, step : std_logic;
-- CSR registers
signal csr_mscratch_we, csr_mstatus_we, csr_mie_we, csr_mtvec_we, csr_mepc_we, csr_mcause_we, csr_mtval_we : std_logic;
signal csr_dcsr_we, csr_dpc_we, csr_dm_data0_we : std_logic;
signal r_csr : csr_registers_t;
begin
-- Execute stage
    execute_ecall <= execute_ecall_i;
    execute_ebreak <= execute_ebreak_i;
    execute_mret <= execute_mret_i;
    execute_dret <= execute_dret_i;
    execute_branch <= execute_opcode_i.jal or execute_opcode_i.branch;

-- Memory stage
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_en_i = '1' then
                memory_branch <= execute_branch;
                memory_ecall <= execute_ecall;
                memory_ebreak <= execute_ebreak;
                memory_mret <= execute_mret;
                memory_pc <= execute_current_pc_i;
                memory_misaligned_load <= execute_misaligned_load;
                memory_misaligned_store <= execute_misaligned_store;
                memory_dret <= execute_dret;
            end if;
        end if;
    end process;

-- Exception handling
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if C_XRET = TRUE then
                async_exception <= ((external_interrupt_i and external_interrupt_en) or (timer_interrupt_i and timer_interrupt_en));
                external_interrupt <= external_interrupt_i and external_interrupt_en;
                timer_interrupt <= timer_interrupt_i and timer_interrupt_en;
            else
                async_exception <= '0';
                external_interrupt <= '0';
                timer_interrupt <= '0';
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            async_exception_pending <= '0';
        elsif rising_edge(clk_i) then
            if async_exception_pending = '0' and ((async_exception = '1' and async_exception_en = '1') or dcsr_step = '1') then
                async_exception_pending <= '1';
            elsif async_exception_pending = '1' and memory_valid_i = '1' then
                async_exception_pending <= '0';
            end if;
        end if;
    end process;

--    nxt_epc <=
--        execute_current_pc_i when epc_sel = '1' else
--        memory_pc;

    nxt_epc <= 
        r_csr.mtvec when exception_async = '1' and dcsr_step = '1' and exception_sync = '1' else 
        memory_target_pc_i when exception_async = '1' and memory_branch_i = '1' else
        execute_current_pc_i when exception_async = '1' and memory_branch_i = '0' else
        memory_pc;

--    epc_sel <= async_exception_pending and load_pc_i;

--    epc_sel <=
--        '0' when ecall = '1' or ebreak = '1' or instruction_address_misaligned = '1' or load_address_misaligned = '1' or store_address_misaligned = '1' else
--        '1' when async_exception_pending = '1' else
--        '-';

    instruction_address_misaligned <=
        memory_branch_i and (memory_target_pc_i(1) or memory_target_pc_i(0)) when C_INSTRUCTION_MISALIGNED = TRUE and G_EXTENSION_C = FALSE else
        memory_branch_i and memory_target_pc_i(0) when C_INSTRUCTION_MISALIGNED = TRUE and G_EXTENSION_C = TRUE else
        '0';
    execute_misaligned_load <= execute_valid_i and execute_opcode_i.load and load_store_address_misaligned and not memory_branch_i when C_LOAD_MISALIGNED = TRUE else '0';
    execute_misaligned_store <= execute_valid_i and execute_opcode_i.store and load_store_address_misaligned and not memory_branch_i when C_STORE_MISALIGNED = TRUE else '0';
    load_store_address_misaligned <= (execute_funct3_i(1) and (memory_address_i(1) or memory_address_i(0))) or (execute_funct3_i(0) and memory_address_i(0));

    misaligned_load_o <= execute_misaligned_load;
    misaligned_store_o <= execute_misaligned_store;

    load_address_misaligned <= memory_misaligned_load;
    store_address_misaligned <= memory_misaligned_store;

    async_exception_en <= r_csr.mstatus(CSR_MSTATUS_MIE);
    external_interrupt_en <= r_csr.mie(CSR_MIE_MEIE);
    timer_interrupt_en <= r_csr.mie(CSR_MIE_MTIE);

    ecall <= memory_ecall and memory_valid_i;
    ebreak <= memory_ebreak and memory_valid_i;
    mret <= memory_mret and memory_valid_i;
    dret <= memory_dret and memory_valid_i;
    step <= dcsr_step and memory_valid_i;

    exception_sync <= ecall or ebreak or instruction_address_misaligned or load_address_misaligned or store_address_misaligned;
    exception_async <= ((async_exception and async_exception_en) or (not debug_mode and (debug_halt or step))) and execute_pc_valid;

    exception_entry <= exception_sync or exception_async;-- and not (memory_branch and memory_valid_i));
    exception_exit <= mret or dret;

    load_pc_o <= exception_entry or exception_exit;

    process (exception_sync, exception_async, exception_exit, r_csr, mret, dret)
    begin
        if (exception_sync or exception_async) = '1' then
            target_pc_o <= r_csr.mtvec(31 downto 2) & "00";
        elsif exception_exit = '1' and mret = '1' then
            if G_EXTENSION_C = TRUE then
                target_pc_o <= r_csr.mepc(31 downto 1) & '0';
            else
                target_pc_o <= r_csr.mepc(31 downto 2) & "00";
            end if;
        elsif exception_exit = '1' and dret = '1' then
            if G_EXTENSION_C = TRUE then
                target_pc_o <= r_csr.dpc(31 downto 1) & '0';
            else
                target_pc_o <= r_csr.dpc(31 downto 2) & "00";
            end if;
        else
            target_pc_o <= (others => 'X');
        end if;
    end process;

    -- add a delay for the pc to be propagated to execute stage
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            execute_pc_valid <= '1';
            if exception_exit = '1' or memory_branch = '1' then
                execute_pc_valid <= '0';
            end if;
        end if;
    end process;

-- CSR logic
    csr_read_enable <= '1' when execute_opcode_i.sys = '1' and execute_funct3_i /= RV32I_FN3_TRAP else '0';
    csr_read_address <= execute_immediate_i(11 downto 0);

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_en_i = '1' then
                read_data <= csr_read_data;
            end if;
            csr_write_enable <= csr_read_enable;
            csr_write_address <= csr_read_address;
            if execute_funct3_i(2) = '1' then
                write_data <= (31 downto 5 => '0') & execute_zimm_i;
            else
                write_data <= execute_rs1_dat_i;
            end if;
        end if;
    end process;
    read_data_o <= read_data;

    csr_machine_we <= csr_write_enable and memory_valid_i; -- csr_write_enable when csr_write_address(11 downto 10) = "00" else '0';

    with csr_read_address select
        csr_read_data <=
            r_csr.mscratch        when CSR_MSCRATCH,
            r_csr.mie             when CSR_MIE,
            r_csr.mstatus         when CSR_MSTATUS,
            r_csr.mtvec           when CSR_MTVEC,
            r_csr.mepc            when CSR_MEPC,
            r_csr.mcause          when CSR_MCAUSE,
            r_csr.mtval           when CSR_MTVAL,
            r_csr.dcsr            when CSR_DCSR,
            r_csr.dpc             when CSR_DPC,
            r_csr.dm_data0        when CSR_DM_DATA0,
            (others => '0') when others;

    with memory_funct3_i(1 downto 0) select
        csr_write_data <=
            write_data or read_data when "10",
            write_data and (not read_data) when "11",
            write_data when others;

-- CSR registers
    process (csr_write_address)
    begin
        csr_mscratch_we <= '0';
        csr_mstatus_we <= '0';
        csr_mie_we <= '0';
        csr_mtvec_we <= '0';
        csr_mepc_we <= '0';
        csr_mcause_we <= '0';
        csr_mtval_we <= '0';
        csr_dcsr_we <= '0';
        csr_dpc_we <= '0';
        csr_dm_data0_we <= '0';
        case csr_write_address is
            when CSR_MSCRATCH => csr_mscratch_we <= '1';
            when CSR_MSTATUS => csr_mstatus_we <= '1';
            when CSR_MIE => csr_mie_we <= '1';
            when CSR_MTVEC => csr_mtvec_we <= '1';
            when CSR_MEPC => csr_mepc_we <= '1';
            when CSR_MCAUSE => csr_mcause_we <= '1';
            when CSR_MTVAL => csr_mtval_we <= '1';
            when CSR_DCSR => csr_dcsr_we <= '1';
            when CSR_DPC => csr_dpc_we <= '1';
            when CSR_DM_DATA0 => csr_dm_data0_we <= '1';
            when others =>
        end case;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            r_csr.mtvec <= (others => '0');
            r_csr.mie <= (others => '0');
        elsif rising_edge(clk_i) then
            if (csr_mtvec_we and csr_machine_we) = '1' then
                r_csr.mtvec <= csr_write_data;
            end if;
            if (csr_mie_we and csr_machine_we) = '1' then
                r_csr.mie <= csr_write_data;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if exception_entry = '1' and ecall = '1' then
                r_csr.mcause <= CSR_MCAUSE_MACHINE_ECALL;
            elsif exception_entry = '1' and ebreak = '1' then
                r_csr.mcause <= CSR_MCAUSE_BREAKPOINT;
            elsif exception_entry = '1' and instruction_address_misaligned = '1' then
                r_csr.mcause <= CSR_MCAUSE_INSTRUCTION_ADDRESS_MISALIGNED;
            elsif exception_entry = '1' and load_address_misaligned = '1' then
                r_csr.mcause <= CSR_MCAUSE_LOAD_ADDRESS_MISALIGNED;
            elsif exception_entry = '1' and store_address_misaligned = '1' then
                r_csr.mcause <= CSR_MCAUSE_STORE_ADDRESS_MISALIGNED;
            elsif exception_entry = '1' and external_interrupt = '1' then
                r_csr.mcause <= CSR_MCAUSE_MACHINE_EXTERNAL_INTERRUPT;
            elsif exception_entry = '1' and timer_interrupt = '1' then
                r_csr.mcause <= CSR_MCAUSE_MACHINE_TIMER_INTERRUPT;
            elsif (csr_mcause_we and csr_machine_we) = '1' then
                r_csr.mcause <= csr_write_data;
            end if;
            if exception_entry = '1' then
                r_csr.mepc <= nxt_epc;
            elsif (csr_mepc_we and csr_machine_we) = '1' then
                r_csr.mepc <= csr_write_data;
            end if;
            if (csr_mscratch_we and csr_machine_we) = '1' then
                r_csr.mscratch <= csr_write_data;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            r_csr.mstatus <= (31 downto 13 => '0') & "11" & (10 downto 0 => '0');
        elsif rising_edge(clk_i) then
            if exception_entry = '1' then
                r_csr.mstatus(7) <= r_csr.mstatus(3);
                -- mstatus.mie = 0
                r_csr.mstatus(3) <= '0';
                -- mstatus.mpp = current privilege mode
                r_csr.mstatus(12 downto 11) <= "11";
            elsif exception_exit = '1' then
                -- privilege set to mstatus.mpp
                -- mstatus.mie = mstatus.mpie
                r_csr.mstatus(3) <= r_csr.mstatus(7);
                r_csr.mstatus(7) <= '1';
                r_csr.mstatus(12 downto 11) <= "11";
            elsif (csr_mstatus_we and csr_machine_we) = '1' then
                r_csr.mstatus <= csr_write_data;
            end if;
        end if;
    end process;


    block_mtval : block
        signal mtval_set : std_logic;
        signal nxt_mtval : std_logic_vector(31 downto 0);
    begin

        nxt_mtval <=
            nxt_epc when ebreak = '1' else
            memory_target_pc_i when instruction_address_misaligned = '1' or load_address_misaligned = '1' or store_address_misaligned = '1' else
--            memory_address_i when (load_address_misaligned or store_address_misaligned) = '1' else
            (others => '-');

        mtval_set <= exception_entry and (ebreak or instruction_address_misaligned or load_address_misaligned or store_address_misaligned);

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                r_csr.mtval <= (others => '0');
            elsif rising_edge(clk_i) then
                if mtval_set = '1' then
                    r_csr.mtval <= nxt_mtval;
                end if;
            end if;
        end process;
    end block;

    block_debug_module : block
        signal dcsr_debugver : std_logic_vector(3 downto 0);
        signal dcsr_ebreakm : std_logic;
        signal dcsr_cause : std_logic_vector(2 downto 0);
        signal dm_data0_wdata : std_logic_vector(31 downto 0);
        signal dm_data0_we : std_logic;
    begin

        process (clk_i, arst_i)
        begin
            if arst_i = '1' then
                dcsr_ebreakm <= '0';
                dcsr_cause <= (others => '0');
                dcsr_step <= '0';
                debug_mode <= '0';
            elsif rising_edge(clk_i) then
                if exception_entry = '1' and debug_mode = '0' and debug_halt = '1' then
                    dcsr_cause <= std_logic_vector(to_unsigned(3, 3)); -- HALTREQ
                elsif exception_entry = '1' and debug_mode = '0' and ebreak = '1' and dcsr_ebreakm = '1' then
                    dcsr_cause <= std_logic_vector(to_unsigned(1, 3)); -- EBREAKM
                elsif exception_entry = '1' and debug_mode = '0' and dcsr_step = '1' then
                    dcsr_cause <= std_logic_vector(to_unsigned(4, 3)); -- STEP
                elsif debug_mode = '1' and csr_dcsr_we = '1' then
                    dcsr_ebreakm <= csr_write_data(15);
                    dcsr_cause <= csr_write_data(8 downto 6);
                    dcsr_step <= csr_write_data(2);
                end if;
                if exception_entry = '1' and debug_mode = '0' and (debug_halt or (ebreak and dcsr_ebreakm) or dcsr_step) = '1' then
                    debug_mode <= '1';
                elsif exception_exit = '1' and debug_mode = '1' and dret = '1' then
                    debug_mode <= '0';
                end if;
            end if;
        end process;

        process (clk_i)
        begin
            if rising_edge(clk_i) then
                if exception_entry = '1' and debug_mode = '0' and ((ebreak = '1' and dcsr_ebreakm = '1') or dcsr_step = '1' or debug_halt = '1') then
                    r_csr.dpc <= nxt_epc;
                elsif debug_mode = '1' and csr_dpc_we = '1' then
                    r_csr.dpc <= csr_write_data;
                end if;
                if dm_data0_we = '1' then
                    r_csr.dm_data0 <= dm_data0_wdata;
                elsif debug_mode = '1' and csr_dm_data0_we = '1' then
                    r_csr.dm_data0 <= csr_write_data;
                end if;
            end if;
        end process;

        dcsr_debugver <= x"4";

        r_csr.dcsr(31 downto 28) <= dcsr_debugver;
        r_csr.dcsr(27 downto 16) <= (others => '0');
        r_csr.dcsr(15) <= dcsr_ebreakm;
        r_csr.dcsr(14 downto 9) <= (others => '0');
        r_csr.dcsr(8 downto 6) <= dcsr_cause;
        r_csr.dcsr(5 downto 3) <= (others => '0');
        r_csr.dcsr(2) <= dcsr_step;
        r_csr.dcsr(1 downto 0) <= (others => '0');

        u_debug_module : entity work.debug_module
            port map (
                arst_i => arst_i,
                clk_i => clk_i,
                debug_mode_i => debug_mode,
                debug_halt_o => debug_halt,
                debug_reset_o => debug_reset,
                debug_adr_i => debug_cmd_adr_i,
                debug_vld_i => debug_cmd_vld_i,
                debug_we_i => debug_cmd_we_i,
                debug_dat_i => debug_cmd_dat_i,
                debug_dat_o => debug_rsp_dat_o,
                debug_vld_o => debug_rsp_vld_o,
                debug_rdy_o => debug_cmd_rdy_o,
                enable_i => fetch_enable_i,
                instr_data_o => instr_data_o,
                instr_valid_o => instr_valid_o,
                csr_data0_dat_o => dm_data0_wdata,
                csr_data0_vld_o => dm_data0_we,
                csr_data0_dat_i => r_csr.dm_data0
            );
    end block;

    exception_async_o <= exception_async;
    exception_sync_o <= exception_sync;
    exception_entry_o <= exception_entry;
    exception_exit_o <= exception_exit;
    mtvec_o <= r_csr.mtvec;
    mepc_o <= r_csr.mepc;
    debug_mode_o <= debug_mode;
    debug_reset_o <= debug_reset;

end architecture rtl;