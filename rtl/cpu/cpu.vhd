library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity cpu is
    generic (
        G_BOOT_ADDRESS : std_logic_vector(31 downto 0) := (others => '0');
        G_WRITEBACK_BYPASS : boolean := FALSE;
        G_FULL_BARREL_SHIFTER : boolean := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        instr_cmd_adr_o : out std_logic_vector(31 downto 0);
        instr_cmd_vld_o : out std_logic;
        instr_cmd_rdy_i : in std_logic;
        instr_rsp_dat_i : in std_logic_vector(31 downto 0);
        instr_rsp_vld_i : in std_logic;
        data_cmd_adr_o : out std_logic_vector(31 downto 0);
        data_cmd_vld_o : out std_logic;
        data_cmd_we_o : out std_logic;
        data_cmd_siz_o : out std_logic_vector(1 downto 0);
        data_cmd_rdy_i : in std_logic;
        data_cmd_dat_o : out std_logic_vector(31 downto 0);
        data_rsp_dat_i : in std_logic_vector(31 downto 0);
        data_rsp_vld_i : in std_logic;
        external_irq_i : in std_logic;
        timer_irq_i : in std_logic
    );
end entity cpu;

architecture rtl of cpu is
    signal booted : std_logic;
-- fetch
    signal fetch_en, fetch_branch, fetch_load, fetch_valid : std_logic;
    signal fetch_pc, fetch_pc_next : unsigned(31 downto 0);
    signal fetch_load_pc, fetch_instr : std_logic_vector(31 downto 0);
-- decode
    signal decode_en, decode_valid : std_logic;
    signal decode_instr, decode_pc, decode_imm : std_logic_vector(31 downto 0);
    signal decode_opcode : opcode_t;
    signal decode_rs1_adr, decode_rs2_adr, decode_rd_adr : std_logic_vector(4 downto 0);
    signal decode_funct3 : std_logic_vector(2 downto 0);
    signal decode_funct7 : std_logic_vector(6 downto 0);
-- execute
    signal execute_en, execute_valid : std_logic;
    signal execute_opcode : opcode_t;
    signal execute_rd_we, execute_mem_write, execute_mem_read : std_logic;
    signal execute_funct3 : std_logic_vector(2 downto 0);
    signal execute_funct7 : std_logic_vector(6 downto 0);
    signal execute_rs1_adr, execute_rs2_adr, execute_rd_adr : std_logic_vector(4 downto 0);
    signal execute_rs1_dat, execute_rs2_dat, execute_imm, execute_pc : std_logic_vector(31 downto 0);
    signal execute_alu_arith_op, execute_alu_signed_op : std_logic;
    signal execute_alu_logic_op : std_logic_vector(1 downto 0);
    signal execute_alu_a, execute_alu_b : std_logic_vector(31 downto 0);
    signal execute_alu_arith : std_logic_vector(32 downto 0);
    signal execute_alu_logic : std_logic_vector(31 downto 0);
    signal execute_alu_lt : std_logic;
    signal execute_alu_address_a, execute_alu_address_b, execute_alu_address_r : std_logic_vector(31 downto 0);
    signal execute_ecall, execute_ebreak, execute_mret : std_logic;
-- execute-shifter
    signal execute_shift_start, execute_shift_ready, execute_shift_done, execute_shift_flush : std_logic;
    signal execute_shift_type : std_logic_vector(1 downto 0);
    signal execute_shift_shmt : std_logic_vector(4 downto 0);
    signal execute_shift_data, execute_shift_result : std_logic_vector(31 downto 0);
-- memory
    signal memory_en, memory_valid : std_logic;
    signal memory_opcode : opcode_t;
    signal memory_rd_we, memory_mem_write, memory_mem_read : std_logic;
    signal memory_funct3 : std_logic_vector(2 downto 0);
    signal memory_funct7 : std_logic_vector(6 downto 0);
    signal memory_pc, memory_branch_pc : std_logic_vector(31 downto 0);
    signal memory_branch, memory_branching : std_logic;
    signal memory_rd_adr : std_logic_vector(4 downto 0);
    signal memory_alu_arith, memory_alu_logic, memory_alu_address, memory_alu_data, memory_rs2_dat : std_logic_vector(31 downto 0);
    signal memory_alu_eq, memory_alu_lt : std_logic;
    signal memory_ecall, memory_ebreak, memory_mret : std_logic;
-- writeback
    signal writeback_en, writeback_valid : std_logic;
    signal writeback_opcode : opcode_t;
    signal writeback_funct3 : std_logic_vector(2 downto 0);
    signal writeback_rd_we, writeback_mem_read : std_logic;
    signal writeback_rd_adr : std_logic_vector(4 downto 0);
    signal writeback_rd_dat, writeback_alu_data, writeback_mem_data : std_logic_vector(31 downto 0);
    signal writeback_mem_adr : std_logic_vector(1 downto 0);
    signal writeback_mem_data8 : std_logic_vector(7 downto 0);
    signal writeback_mem_data16 : std_logic_vector(15 downto 0);
-- control unit
    signal fetch_stall, decode_stall, execute_stall, memory_stall, writeback_stall : std_logic;
    signal decode_flush, execute_flush, memory_flush, writeback_flush : std_logic;
    signal rs1_hazard, rs2_hazard : std_logic;
    signal decode_op_use_rs1, decode_op_use_rs2 : std_logic;
    signal decode_rs1_zero, decode_rs2_zero : std_logic;
    signal decode_execute_rs1_dependency, decode_execute_rs2_dependency : std_logic;
    signal decode_memory_rs1_dependency, decode_memory_rs2_dependency : std_logic;
    signal decode_rs1_dependency, decode_rs2_dependency : std_logic;
-- register file
    signal regfile_rs1_en, regfile_rs2_en, regfile_rd_we : std_logic;
-- CSR
    signal csr_enable : std_logic;
    signal csr_address : std_logic_vector(11 downto 0);
    signal csr_write_data, csr_read_data : std_logic_vector(31 downto 0);
    signal csr_ecall, csr_ebreak : std_logic;
    signal csr_exeception_pc, csr_exeception_entry_vector, csr_exeception_exit_vector : std_logic_vector(31 downto 0);
    signal csr_mstatus, csr_mie, csr_mtvec, csr_mepc : std_logic_vector(31 downto 0);
    signal csr_execption_entry, csr_execption_exit : std_logic;
    signal csr_cause_external_irq, csr_cause_timer_irq : std_logic;
-- interrupt handler
    signal interrupt_request, interrupt_taken : std_logic;
begin
-- fetch stage
    fetch_branch <= ((memory_branch or memory_ecall or memory_ebreak or memory_mret or interrupt_taken) and memory_valid);
    fetch_load <= fetch_branch or not booted;
    fetch_load_pc <= 
        G_BOOT_ADDRESS when booted = '0' else
        csr_exeception_entry_vector when (memory_ecall or memory_ebreak or interrupt_taken) = '1' else
        csr_exeception_exit_vector when memory_mret = '1' else
        memory_branch_pc;

    fetch_pc_next <= 
        unsigned(fetch_load_pc) when fetch_load = '1' else
        fetch_pc + 4;

    fetch_en <= not fetch_stall;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            booted <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                booted <= '0';
            else
                booted <= '1';
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if fetch_en = '1' then
                fetch_pc <= fetch_pc_next;
            end if;
        end if;
    end process;

    instr_cmd_adr_o <= std_logic_vector(fetch_pc);
    instr_cmd_vld_o <= fetch_en and booted;
    fetch_instr <= instr_rsp_dat_i;
    fetch_valid <= instr_rsp_vld_i;

-- decode stage
    decode_en <= not decode_stall;
    decode_instr <= fetch_instr;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            decode_valid <= '0';
        elsif rising_edge(clk_i) then
            if decode_flush = '1' then
                decode_valid <= '0';
            elsif decode_en = '1' then
                decode_valid <= fetch_en;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if decode_en = '1' then
                decode_pc <= std_logic_vector(fetch_pc);
            end if;
        end if;
    end process;

    decode_opcode.lui <=     '1' when decode_instr(6 downto 0) = RV32I_OP_LUI else '0';
    decode_opcode.auipc <=   '1' when decode_instr(6 downto 0) = RV32I_OP_AUIPC else '0';
    decode_opcode.jal <=     '1' when decode_instr(6 downto 0) = RV32I_OP_JAL else '0';
    decode_opcode.jalr <=    '1' when decode_instr(6 downto 0) = RV32I_OP_JALR else '0';
    decode_opcode.branch <=  '1' when decode_instr(6 downto 0) = RV32I_OP_BRANCH else '0';
    decode_opcode.load <=    '1' when decode_instr(6 downto 0) = RV32I_OP_LOAD else '0';
    decode_opcode.store <=   '1' when decode_instr(6 downto 0) = RV32I_OP_STORE else '0';
    decode_opcode.reg_imm <= '1' when decode_instr(6 downto 0) = RV32I_OP_REG_IMM else '0';
    decode_opcode.reg_reg <= '1' when decode_instr(6 downto 0) = RV32I_OP_REG_REG else '0';
    decode_opcode.fence <=   '1' when decode_instr(6 downto 0) = RV32I_OP_FENCE else '0';
    decode_opcode.sys <=     '1' when decode_instr(6 downto 0) = RV32I_OP_SYS else '0';
    decode_opcode.illegal <= '0';

    decode_rs1_adr <= (others => '0') when decode_opcode.lui = '1' else decode_instr(19 downto 15);
    decode_rs2_adr <= (others => '0') when (decode_opcode.jalr or decode_opcode.jal) = '1' else decode_instr(24 downto 20);
    decode_rd_adr <= decode_instr(11 downto 7);

    decode_funct3 <= decode_instr(14 downto 12);
    decode_funct7 <= decode_instr(31 downto 25);

    process (decode_instr)
    begin
        case decode_instr(6 downto 0) is
            when RV32I_OP_LUI | RV32I_OP_AUIPC => 
                decode_imm <= decode_instr(31 downto 12) & (0 to 11 => '0');
            when RV32I_OP_JAL => 
                decode_imm <= (20 to 31 => decode_instr(31)) & decode_instr(19 downto 12) & decode_instr(20) & decode_instr(30 downto 25) & decode_instr(24 downto 21) & '0';
            when RV32I_OP_JALR | RV32I_OP_LOAD | RV32I_OP_REG_IMM | RV32I_OP_SYS => 
                decode_imm <= (11 to 31 => decode_instr(31)) & decode_instr(30 downto 25) & decode_instr(24 downto 21) & decode_instr(20);
            when RV32I_OP_BRANCH => 
                decode_imm <= (12 to 31 => decode_instr(31)) & decode_instr(7) & decode_instr(30 downto 25) & decode_instr(11 downto 8) & '0';
            when RV32I_OP_STORE =>
                decode_imm <= (11 to 31 => decode_instr(31)) & decode_instr(30 downto 25) & decode_instr(11 downto 8) & decode_instr(7);
            when others => 
                decode_imm <= (others => '0');
        end case;
    end process;

-- execute stage
    execute_en <= not execute_stall;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            execute_valid <= '0';
        elsif rising_edge(clk_i) then
            if execute_en = '1' then
                if execute_flush = '1' then
                    execute_valid <= '0';
                else
                    execute_valid <= decode_valid;
                end if;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if execute_en = '1' then
                execute_opcode <= decode_opcode;
                execute_pc <= decode_pc;
                execute_imm <= decode_imm;
                execute_rs1_adr <= decode_rs1_adr;
                execute_rs2_adr <= decode_rs2_adr;
                execute_rd_adr <= decode_rd_adr;
                execute_funct3 <= decode_funct3;
                execute_funct7 <= decode_funct7;
            end if;
        end if;
    end process;

    execute_rd_we <= execute_opcode.reg_reg or execute_opcode.load or execute_opcode.reg_imm or execute_opcode.sys or execute_opcode.jalr or execute_opcode.lui or execute_opcode.auipc or execute_opcode.jal;
    execute_mem_write <= execute_opcode.store;
    execute_mem_read <= execute_opcode.load;

    execute_ecall  <= '1' when execute_opcode.sys = '1' and execute_funct3 = RV32I_FN3_TRAP and execute_imm(1 downto 0) = "00" else '0';
    execute_ebreak <= '1' when execute_opcode.sys = '1' and execute_funct3 = RV32I_FN3_TRAP and execute_imm(1 downto 0) = "01" else '0';
    execute_mret   <= '1' when execute_opcode.sys = '1' and execute_funct3 = RV32I_FN3_TRAP and execute_imm(1 downto 0) = "10" else '0';

    execute_alu_a <= 
        execute_pc when execute_opcode.auipc = '1' or execute_opcode.jalr = '1' or execute_opcode.jal = '1' else
        execute_rs1_dat;

    execute_alu_b <= 
        execute_imm when (execute_opcode.lui or execute_opcode.reg_imm or execute_opcode.auipc) = '1' else
        execute_rs2_dat(31 downto 3) & (execute_rs2_dat(2) or execute_opcode.jalr or execute_opcode.jal) & execute_rs2_dat(1 downto 0);

    execute_alu_arith_op <= '1' when (execute_funct7(5) = '1' and execute_opcode.reg_reg = '1') or ((execute_opcode.reg_reg = '1' or execute_opcode.reg_imm = '1') and execute_funct3(1) = '1') or (execute_opcode.branch = '1') else '0';
    execute_alu_signed_op <= '1' when (execute_opcode.branch = '1' and execute_funct3(2 downto 1) = "10") or ((execute_opcode.reg_imm or execute_opcode.reg_reg) = '1' and execute_funct3(1 downto 0) = "10") else '0';
    execute_alu_logic_op <= execute_funct3(1 downto 0);

    u_alu_1 : entity work.alu
        port map (
            a_i => execute_alu_a,
            b_i => execute_alu_b,
            signed_i => execute_alu_signed_op,
            arith_op_i => execute_alu_arith_op,
            logic_op_i => execute_alu_logic_op,
            arith_result_o => execute_alu_arith,
            logic_result_o => execute_alu_logic
        );
    
    execute_alu_lt <= execute_alu_arith(execute_alu_arith'left);

    execute_alu_address_a <= execute_pc when (execute_opcode.jal or execute_opcode.branch) = '1' else execute_rs1_dat;
    execute_alu_address_b <= execute_imm;
    execute_alu_address_r <= std_logic_vector(unsigned(execute_alu_address_a) + unsigned(execute_alu_address_b));

-- execute-shifter
    execute_shift_shmt <= 
        execute_imm(4 downto 0) when execute_opcode.reg_imm = '1' else
        execute_rs2_dat(4 downto 0);

    execute_shift_type <= 
        "10" when execute_funct3 = RV32I_FN3_SR and execute_funct7(5) = '0' else
        "11" when execute_funct3 = RV32I_FN3_SR and execute_funct7(5) = '1' else
        "00";

    execute_shift_data <= execute_rs1_dat;

    execute_shift_start <= 
        (execute_en and execute_valid) when (execute_opcode.reg_imm or execute_opcode.reg_reg) = '1' and (execute_funct3 = RV32I_FN3_SL or execute_funct3 = RV32I_FN3_SR) else
        '0';

--    execute_shift_flush <= execute_flush or srst_i;
    execute_shift_flush <= srst_i;

    u_shifter : entity work.shifter
        generic map (
            G_FULL_BARREL_SHIFTER => G_FULL_BARREL_SHIFTER
        )
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => execute_shift_flush,
            shift_i => execute_shift_shmt,
            type_i => execute_shift_type,
            data_i => execute_shift_data,
            start_i => execute_shift_start,
            data_o => execute_shift_result,
            done_o => execute_shift_done,
            ready_o => execute_shift_ready
        );


-- memory stage
    memory_en <= not memory_stall;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            memory_valid <= '0';
        elsif rising_edge(clk_i) then
            if memory_en = '1' then
                if memory_flush = '1' then
                    memory_valid <= '0';
                else
                    memory_valid <= execute_valid;
                end if;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_en = '1' then
                memory_rd_we <= execute_rd_we;
                memory_mem_write <= execute_mem_write;
                memory_mem_read <= execute_mem_read;
                memory_opcode <= execute_opcode;
                memory_rd_adr <= execute_rd_adr;
                memory_funct3 <= execute_funct3;
                memory_funct7 <= execute_funct7;
                memory_alu_arith <= execute_alu_arith(execute_alu_arith'left - 1 downto 0);
                memory_alu_logic <= execute_alu_logic;
                memory_alu_lt <= execute_alu_lt;
                memory_alu_address <= execute_alu_address_r;
                memory_rs2_dat <= execute_rs2_dat;
                memory_pc <= execute_pc;
                memory_ecall <= execute_ecall;
                memory_ebreak <= execute_ebreak;
                memory_mret <= execute_mret;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_valid = '1' then
                memory_branching <= memory_branch;
            elsif decode_valid = '1' then
                memory_branching <= '0';
            end if;
        end if;
    end process;

    memory_alu_eq <= '1' when memory_alu_arith(31 downto 0) = (0 to 31 => '0') else '0';

    process (memory_opcode, memory_alu_eq, memory_alu_lt, memory_funct3)
    begin
        if (memory_opcode.jal or memory_opcode.jalr) = '1' then
            memory_branch <= '1';
        elsif memory_opcode.branch = '1' then
            case memory_funct3 is
                when RV32I_FN3_BEQ => memory_branch <= memory_alu_eq;
                when RV32I_FN3_BNE => memory_branch <= not memory_alu_eq;
                when RV32I_FN3_BLT | RV32I_FN3_BLTU => memory_branch <= memory_alu_lt;
                when RV32I_FN3_BGE | RV32I_FN3_BGEU => memory_branch <= not memory_alu_lt;            
                when others => memory_branch <= '0';
            end case;
        else
            memory_branch <= '0';
        end if;
    end process;
    memory_branch_pc <= memory_alu_address;

    memory_alu_data <= 
        memory_alu_logic when ((memory_opcode.reg_imm or memory_opcode.reg_reg) = '1' and (memory_funct3 = RV32I_FN3_XOR or memory_funct3 = RV32I_FN3_OR or memory_funct3 = RV32I_FN3_AND)) else
        execute_shift_result when (memory_opcode.reg_imm or memory_opcode.reg_reg) = '1' and (memory_funct3 = RV32I_FN3_SL or memory_funct3 = RV32I_FN3_SR) else
        (1 to 31 => '0') & memory_alu_lt when (memory_opcode.reg_imm or memory_opcode.reg_reg) = '1' and (memory_funct3 = RV32I_FN3_SLT or memory_funct3 = RV32I_FN3_SLTU) else
        memory_alu_arith(31 downto 0);

    data_cmd_adr_o <= memory_alu_address;
    data_cmd_dat_o <= 
        memory_rs2_dat(7 downto 0) & memory_rs2_dat(7 downto 0) & memory_rs2_dat(7 downto 0) & memory_rs2_dat(7 downto 0) when memory_funct3(1 downto 0) = "00" else
        memory_rs2_dat(15 downto 0) & memory_rs2_dat(15 downto 0) when memory_funct3(1 downto 0) = "01" else
        memory_rs2_dat;
    data_cmd_vld_o <= (memory_mem_write or memory_mem_read) and memory_valid;
    data_cmd_we_o <= memory_mem_write and memory_valid;
    data_cmd_siz_o <= memory_funct3(1 downto 0);

-- memory-csr
    csr_enable <= (memory_en and memory_valid) when memory_opcode.sys = '1' and memory_funct3 /= "000" else '0';
    csr_execption_entry <= (memory_en and memory_valid and (memory_ecall or memory_ebreak)) or interrupt_taken;
    csr_exeception_pc <= 
        memory_pc when (memory_ecall or memory_ebreak) = '1' else
        memory_branch_pc when memory_branch = '1' else
        execute_pc;
    csr_execption_exit <= memory_en and memory_valid and memory_mret;

    csr_ecall <= memory_ecall;
    csr_ebreak <= memory_ebreak;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_en = '1' then
                csr_address <= execute_imm(11 downto 0);
                if execute_funct3(2) = '1' then
                    csr_write_data <= (5 to 31 => '0') & execute_rs1_adr;
                else
                    csr_write_data <= execute_rs1_dat;
                end if;
            end if;
        end if;
    end process;

    u_csr : entity work.csr
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            enable_i => csr_enable,
            funct3_i => memory_funct3,
            address_i => csr_address,
            data_i => csr_write_data,
            data_o => csr_read_data,
            exception_pc_i => csr_exeception_pc,
            exception_taken_i => csr_execption_entry,
            exception_exit_i => csr_execption_exit,
            ecall_i => csr_ecall,
            ebreak_i => csr_ebreak,
            cause_external_irq_i => csr_cause_external_irq,
            cause_timer_irq_i => csr_cause_timer_irq,
            mstatus_o => csr_mstatus,
            mie_o => csr_mie,
            mtvec_o => csr_mtvec,
            mepc_o => csr_mepc
        );

    csr_exeception_entry_vector <= csr_mtvec;
    csr_exeception_exit_vector <= csr_mepc;

-- writeback stage
    writeback_en <= not writeback_stall;
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            writeback_valid <= '0';
        elsif rising_edge(clk_i) then
            if writeback_en = '1' then
                if writeback_flush = '1' then
                    writeback_valid <= '0';
                else
                    writeback_valid <= memory_valid and execute_shift_ready;
                end if;
            end if;
        end if;
    end process;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if writeback_en = '1' then
                writeback_rd_we <= memory_rd_we;
                writeback_mem_read <= memory_mem_read;
                writeback_opcode <= memory_opcode;
                writeback_rd_adr <= memory_rd_adr;
                writeback_alu_data <= memory_alu_data;
                writeback_funct3 <= memory_funct3;
                writeback_mem_adr <= memory_alu_address(1 downto 0);
            end if;
        end if;
    end process;

    with writeback_mem_adr select
        writeback_mem_data8 <= 
            data_rsp_dat_i(7 downto 0)   when "00",
            data_rsp_dat_i(15 downto 8)  when "01",
            data_rsp_dat_i(23 downto 16) when "10",
            data_rsp_dat_i(31 downto 24) when "11",
            (others => '-') when others;
    
    writeback_mem_data16 <= 
        data_rsp_dat_i(15 downto 0) when writeback_mem_adr(1) = '0' else
        data_rsp_dat_i(31 downto 16);

    writeback_mem_data <= 
        (8 to 31 => (not writeback_funct3(2) and writeback_mem_data8(7))) & writeback_mem_data8 when writeback_funct3(1 downto 0) = "00" else
        (16 to 31 => (not writeback_funct3(2) and writeback_mem_data16(15))) & writeback_mem_data16 when writeback_funct3(1 downto 0) = "01" else
        data_rsp_dat_i;

    writeback_rd_dat <= 
        writeback_mem_data when writeback_mem_read = '1' else
        csr_read_data when writeback_opcode.sys = '1' else 
        writeback_alu_data;

-- regfile
    regfile_rs1_en <= execute_en;
    regfile_rs2_en <= execute_en;
    regfile_rd_we <= writeback_valid and writeback_rd_we;

    u_regfile : entity work.regfile
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            rs1_en_i => regfile_rs1_en,
            rs1_adr_i => decode_rs1_adr,
            rs1_dat_o => execute_rs1_dat,
            rs2_en_i => regfile_rs2_en,
            rs2_adr_i => decode_rs2_adr,
            rs2_dat_o => execute_rs2_dat,
            rd_adr_i => writeback_rd_adr,
            rd_we_i => regfile_rd_we,
            rd_dat_i => writeback_rd_dat
        );

-- control unit
    decode_op_use_rs1 <= decode_opcode.reg_reg or decode_opcode.load or decode_opcode.reg_imm or decode_opcode.jalr or decode_opcode.store or decode_opcode.branch or decode_opcode.sys;
    decode_op_use_rs2 <= decode_opcode.reg_reg or decode_opcode.store or decode_opcode.branch;
    decode_rs1_zero <= '1' when unsigned(decode_rs1_adr) = 0 else '0';
    decode_rs2_zero <= '1' when unsigned(decode_rs2_adr) = 0 else '0';
    decode_execute_rs1_dependency <= (execute_rd_we and execute_valid) when decode_rs1_adr = execute_rd_adr else '0';
    decode_execute_rs2_dependency <= (execute_rd_we and execute_valid) when decode_rs2_adr = execute_rd_adr else '0';
    decode_memory_rs1_dependency <= (memory_rd_we and memory_valid) when decode_rs1_adr = memory_rd_adr else '0';
    decode_memory_rs2_dependency <= (memory_rd_we and memory_valid) when decode_rs2_adr = memory_rd_adr else '0';

    decode_rs1_dependency <= decode_op_use_rs1 when decode_rs1_zero = '0' and (decode_execute_rs1_dependency or decode_memory_rs1_dependency) = '1' else '0';
    decode_rs2_dependency <= decode_op_use_rs2 when decode_rs2_zero = '0' and (decode_execute_rs2_dependency or decode_memory_rs2_dependency) = '1' else '0';

    fetch_stall <= (decode_rs1_dependency or decode_rs2_dependency or memory_stall) and not fetch_load;
    decode_stall <= (decode_rs1_dependency or decode_rs2_dependency or memory_stall);
    execute_stall <= memory_stall;
    memory_stall <= ((memory_mem_write or memory_mem_read) and memory_valid and not data_cmd_rdy_i) or not execute_shift_ready;
    writeback_stall <= '0';

    decode_flush <= fetch_load;
    execute_flush <= decode_rs1_dependency or decode_rs2_dependency or fetch_load;
    memory_flush <= fetch_load;
    writeback_flush <= '0';

-- interrupt handler
    u_interrupt_handler : entity work.interrupt_handler
        port map (
            arst_i => arst_i,
            clk_i => clk_i,
            srst_i => srst_i,
            mstatus_i => csr_mstatus,
            mie_i => csr_mie,
            external_irq_i => external_irq_i,
            timer_irq_i => timer_irq_i,
            exception_valid_o => interrupt_request,
            exception_taken_i => interrupt_taken,
            cause_external_irq_o => csr_cause_external_irq,
            cause_timer_irq_o => csr_cause_timer_irq
        );

    interrupt_taken <= interrupt_request and memory_valid and memory_en and execute_valid;

end architecture rtl;