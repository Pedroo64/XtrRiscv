library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;

use work.rv32i_pkg.all;
use work.csr_def.all;
use work.vhdl_utils.all;

entity cpu_checker is
    generic (
        G_EXTENSION_C : BOOLEAN := FALSE;
        G_EXTENSION_ZICSR : BOOLEAN := FALSE
    );
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        decode_valid_i : in std_logic;
        decode_instr_i : in std_logic_vector(31 downto 0);
        decode_instr_compress_i : in std_logic;
        decode_rs1_dat_i : in std_logic_vector(31 downto 0);
        decode_rs2_dat_i : in std_logic_vector(31 downto 0);
        execute_enable_i : in std_logic;
        execute_flush_i : in std_logic;
        execute_current_pc_i : in std_logic_vector(31 downto 0);
        memory_enable_i : in std_logic;
        memory_flush_i : in std_logic;
        writeback_enable_i : in std_logic;
        writeback_flush_i : in std_logic;
        mem_cmd_adr_i : in std_logic_vector(31 downto 0);
        mem_cmd_dat_i : in std_logic_vector(31 downto 0);
        mem_cmd_vld_i : in std_logic;
        mem_cmd_we_i : in std_logic;
        mem_rsp_dat_i : in std_logic_vector(31 downto 0);
        mem_rsp_vld_i : in std_logic;
        fetch_enable_i : in std_logic;
        fetch_load_pc_i : in std_logic;
        fetch_target_pc_i : in std_logic_vector(31 downto 0);
        csr_exception_entry_i : in std_logic;
        csr_exception_exit_i : in std_logic;
        csr_exception_sync_i : in std_logic;
        csr_exception_async_i : in std_logic;
        csr_mtvec_i : in std_logic_vector(31 downto 0);
        csr_mepc_i : in std_logic_vector(31 downto 0);
        regfile_rd_we_i : in std_logic;
        regfile_rd_dat_i : in std_logic_vector(31 downto 0);
        regfile_rd_adr_i : in std_logic_vector(4 downto 0)
    );
end entity cpu_checker;

architecture rtl of cpu_checker is
-- pipeline
    signal execute_valid, memory_valid, writeback_valid : std_logic;
    signal execute_current_pc, memory_current_pc, writeback_current_pc : std_logic_vector(31 downto 0);
-- decode
    signal decode_opcode : std_logic_vector(6 downto 0);
    signal decode_rd_we, decode_compressed : std_logic;
    signal decode_rd_adr : std_logic_vector(4 downto 0);
    signal decode_funct3 : std_logic_vector(2 downto 0);
    signal decode_funct7 : std_logic_vector(6 downto 0);
    signal decode_imm_i, decode_imm_s, decode_imm_b, decode_imm_u, decode_imm_j, decode_imm : std_logic_vector(31 downto 0);
-- execute
    signal execute_opcode, execute_funct7 : std_logic_vector(6 downto 0);
    signal execute_funct3 : std_logic_vector(2 downto 0);
    signal execute_rs1_dat, execute_rs2_dat, execute_immediate : std_logic_vector(31 downto 0);
    signal execute_next_pc, execute_mem_adr, execute_mem_dat : std_logic_vector(31 downto 0);
    signal execute_load_pc, execute_rd_we : std_logic;
    signal execute_rd_adr : std_logic_vector(4 downto 0);
    signal execute_alu, execute_rd_dat : std_logic_vector(31 downto 0);
    signal execute_mul : std_logic_vector(63 downto 0);
    signal execute_div, execute_rem : std_logic_vector(32 downto 0);
    signal execute_compressed : std_logic;
    signal execute_rd_check_en : std_logic;
-- memory
    signal memory_opcode, memory_funct7 : std_logic_vector(6 downto 0);
    signal memory_funct3 : std_logic_vector(2 downto 0);
    signal memory_rd_adr : std_logic_vector(4 downto 0);
    signal memory_rd_dat, memory_next_pc, memory_mem_adr, memory_mem_dat, memory_mem_cmd_dat : std_logic_vector(31 downto 0);
    signal memory_rd_we, memory_load_pc : std_logic;
-- writeback
    signal writeback_opcode, writeback_funct7 : std_logic_vector(6 downto 0);
    signal writeback_funct3 : std_logic_vector(2 downto 0);
    signal writeback_rd_adr : std_logic_vector(4 downto 0);
    signal writeback_rd_dat : std_logic_vector(31 downto 0);
    signal writeback_rd_we : std_logic;
    signal writeback_rsp_adr : std_logic_vector(1 downto 0);
    signal writeback_mem_rsp_dat : std_logic_vector(31 downto 0);
-- regfile
    signal regfile_rd_we : std_logic;
    signal regfile_rd_dat : std_logic_vector(31 downto 0);
    signal regfile_rd_adr : std_logic_vector(4 downto 0);
-- branching
    signal load_pc : std_logic;
    signal target_pc : std_logic_vector(31 downto 0);
-- memory
    signal mem_cmd_adr : std_logic_vector(31 downto 0);
    signal mem_cmd_dat : std_logic_vector(31 downto 0);
    signal mem_cmd_vld, mem_cmd_we, mem_rsp_vld : std_logic;
    signal mem_rsp_dat : std_logic_vector(31 downto 0);
-- exceptions
    signal execute_ecall, execute_ebreak, execute_mret : std_logic;
    signal memory_ecall, memory_ebreak, memory_mret : std_logic;
    signal ecall, ebreak, mret : std_logic;
    signal instruction_misaligned : std_logic;
    signal load_misaligned, store_misaligned : std_logic;
    signal d_sync_exception_entry, d_async_exception_entry : std_logic;
    signal d_exception_pc : std_logic_vector(31 downto 0);
begin
    -- Pipeline
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            execute_valid <= '0';
            memory_valid <= '0';
            writeback_valid <= '0';
        elsif rising_edge(clk_i) then
            if execute_enable_i = '1' then
                execute_valid <= decode_valid_i and not execute_flush_i;
            end if;
            if memory_enable_i = '1' then
                memory_valid <= execute_valid and not memory_flush_i;
            end if;
            if writeback_enable_i = '1' then
                writeback_valid <= memory_valid and not writeback_flush_i;
            end if;
        end if;
    end process;
    execute_current_pc <= execute_current_pc_i;
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_enable_i = '1' then
                memory_current_pc <= execute_current_pc;
            end if;
            if writeback_enable_i = '1' then
                writeback_current_pc <= memory_current_pc;
            end if;
        end if;
    end process;
    -- Decode stage
    decode_opcode <= decode_instr_i(6 downto 0);
    decode_rd_adr <= decode_instr_i(11 downto 7);
    decode_funct3 <= decode_instr_i(14 downto 12);
    decode_funct7 <= decode_instr_i(31 downto 25);
    decode_imm_i <= (31 downto 12 => decode_instr_i(31)) & decode_instr_i(31 downto 20);
    decode_imm_s <= (31 downto 12 => decode_instr_i(31)) & decode_instr_i(31 downto 25) & decode_instr_i(11 downto 7);
    decode_imm_b <= (31 downto 12 => decode_instr_i(31)) & decode_instr_i(7) & decode_instr_i(30 downto 25) & decode_instr_i(11 downto 8) & '0';
    decode_imm_u <= decode_instr_i(31 downto 12) & (11 downto 0 => '0');
    decode_imm_j <= (31 downto 20 => decode_instr_i(31)) & decode_instr_i(19 downto 12) & decode_instr_i(20) & decode_instr_i(30 downto 21) & '0';
    decode_compressed <= decode_instr_compress_i;
    process (decode_opcode, decode_imm_u, decode_imm_i, decode_imm_j, decode_imm_b, decode_imm_s)
    begin
        case decode_opcode is
            when RV32I_OP_LUI     => decode_imm <= decode_imm_u; decode_rd_we <= '1';
            when RV32I_OP_AUIPC   => decode_imm <= decode_imm_u; decode_rd_we <= '1';
            when RV32I_OP_JAL     => decode_imm <= decode_imm_j; decode_rd_we <= '1';
            when RV32I_OP_JALR    => decode_imm <= decode_imm_i; decode_rd_we <= '1';
            when RV32I_OP_BRANCH  => decode_imm <= decode_imm_b; decode_rd_we <= '0';
            when RV32I_OP_LOAD    => decode_imm <= decode_imm_i; decode_rd_we <= '1';
            when RV32I_OP_STORE   => decode_imm <= decode_imm_s; decode_rd_we <= '0';
            when RV32I_OP_REG_IMM => decode_imm <= decode_imm_i; decode_rd_we <= '1';
            when RV32I_OP_REG_REG => decode_imm <= (others => 'X'); decode_rd_we <= '1';
            when RV32I_OP_FENCE   => decode_imm <= (others => 'X'); decode_rd_we <= '0';
            when RV32I_OP_SYS     => decode_imm <= decode_imm_i; decode_rd_we <= '1';
            when others =>
        end case;
    end process;
    -- Execute stage
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if execute_enable_i = '1' then
                execute_opcode <= decode_opcode;
                execute_funct3 <= decode_funct3;
                execute_funct7 <= decode_funct7;
                execute_rd_adr <= decode_rd_adr;
                execute_rd_we <= decode_rd_we;
                execute_immediate <= decode_imm;
                execute_compressed <= decode_compressed;
                execute_rs1_dat <= decode_rs1_dat_i;
                execute_rs2_dat <= decode_rs2_dat_i;
            end if;
        end if;
    end process;

    process (execute_opcode, execute_immediate, execute_current_pc_i, execute_rs1_dat, execute_rs2_dat, execute_funct3, execute_funct7, execute_compressed)
    begin
        execute_alu <= (others => 'X');
        case execute_opcode is
            when RV32I_OP_LUI =>
                execute_alu <= execute_immediate;
            when RV32I_OP_AUIPC =>
                execute_alu <= std_logic_vector(unsigned(execute_current_pc_i) + unsigned(execute_immediate));
            when RV32I_OP_JAL | RV32I_OP_JALR =>
                execute_alu <= std_logic_vector(unsigned(execute_current_pc_i) + 4);
                if execute_compressed = '1' then
                    execute_alu <= std_logic_vector(unsigned(execute_current_pc_i) + 2);
                end if;
            when RV32I_OP_REG_IMM =>
                case execute_funct3 is
                    when RV32I_FN3_ADD =>
                        execute_alu <= std_logic_vector(unsigned(execute_rs1_dat) + unsigned(execute_immediate));
                    when RV32I_FN3_SL =>
                        execute_alu <= std_logic_vector(shift_left(unsigned(execute_rs1_dat), to_integer(unsigned(execute_immediate(4 downto 0)))));
                    when RV32I_FN3_SLT =>
                        execute_alu <= (others => '0');
                        if signed(execute_rs1_dat) < signed(execute_immediate) then
                            execute_alu(0) <= '1';
                        end if;
                    when RV32I_FN3_SLTU =>
                        execute_alu <= (others => '0');
                        if unsigned(execute_rs1_dat) < unsigned(execute_immediate) then
                            execute_alu(0) <= '1';
                        end if;
                    when RV32I_FN3_XOR =>
                        execute_alu <= execute_rs1_dat xor execute_immediate;
                    when RV32I_FN3_SR =>
                        execute_alu <= std_logic_vector(shift_right(unsigned(execute_rs1_dat), to_integer(unsigned(execute_immediate(4 downto 0)))));
                        if execute_funct7(5) = '1' then
                            execute_alu <= std_logic_vector(shift_right(signed(execute_rs1_dat), to_integer(unsigned(execute_immediate(4 downto 0)))));
                        end if;
                    when RV32I_FN3_OR =>
                        execute_alu <= execute_rs1_dat or execute_immediate;
                    when RV32I_FN3_AND =>
                        execute_alu <= execute_rs1_dat and execute_immediate;
                    when others =>
                end case;
            when RV32I_OP_REG_REG =>
                case execute_funct3 is
                    when RV32I_FN3_ADD =>
                        if execute_funct7(5) = '0' then
                            execute_alu <= std_logic_vector(unsigned(execute_rs1_dat) + unsigned(execute_rs2_dat));
                        else
                            execute_alu <= std_logic_vector(unsigned(execute_rs1_dat) - unsigned(execute_rs2_dat));
                        end if;
                    when RV32I_FN3_SL =>
                        execute_alu <= std_logic_vector(shift_left(unsigned(execute_rs1_dat), to_integer(unsigned(execute_rs2_dat(4 downto 0)))));
                    when RV32I_FN3_SLT =>
                        execute_alu <= (others => '0');
                        if signed(execute_rs1_dat) < signed(execute_rs2_dat) then
                            execute_alu(0) <= '1';
                        end if;
                    when RV32I_FN3_SLTU =>
                        execute_alu <= (others => '0');
                        if unsigned(execute_rs1_dat) < unsigned(execute_rs2_dat) then
                            execute_alu(0) <= '1';
                        end if;
                    when RV32I_FN3_XOR =>
                        execute_alu <= execute_rs1_dat xor execute_rs2_dat;
                    when RV32I_FN3_SR =>
                        execute_alu <= std_logic_vector(shift_right(unsigned(execute_rs1_dat), to_integer(unsigned(execute_rs2_dat(4 downto 0)))));
                        if execute_funct7(5) = '1' then
                            execute_alu <= std_logic_vector(shift_right(signed(execute_rs1_dat), to_integer(unsigned(execute_rs2_dat(4 downto 0)))));
                        end if;
                    when RV32I_FN3_OR =>
                        execute_alu <= execute_rs1_dat or execute_rs2_dat;
                    when RV32I_FN3_AND =>
                        execute_alu <= execute_rs1_dat and execute_rs2_dat;
                    when others =>
                end case;
            when others =>
        end case;
    end process;

    process (execute_opcode, execute_current_pc_i, execute_immediate, execute_rs1_dat, execute_funct3, csr_mtvec_i, csr_mepc_i)
    begin
        execute_next_pc <= (others => 'X');
        case execute_opcode is
            when RV32I_OP_JAL | RV32I_OP_BRANCH =>
                execute_next_pc <= std_logic_vector(unsigned(execute_current_pc_i) + unsigned(execute_immediate));
            when RV32I_OP_JALR =>
                execute_next_pc <= std_logic_vector(unsigned(execute_rs1_dat) + unsigned(execute_immediate));
            when RV32I_OP_SYS =>
                if execute_funct3 = "000" then
                    case execute_immediate(11 downto 0) is
                        when CSR_FN12_ECALL | CSR_FN12_EBREAK =>
                            execute_next_pc <= csr_mtvec_i;
                        when CSR_FN12_MRET =>
                            execute_next_pc <= csr_mepc_i;
                        when others =>
                    end case;
                end if;
            when others =>
        end case;
    end process;

    process (execute_opcode, execute_rs1_dat, execute_rs2_dat, execute_funct3, execute_immediate)
    begin
        execute_load_pc <= '0';
        execute_ecall <= '0';
        execute_ebreak <= '0';
        execute_mret <= '0';
        case execute_opcode is
            when RV32I_OP_JAL | RV32I_OP_JALR =>
                execute_load_pc <= '1';
            when RV32I_OP_BRANCH =>
                case execute_funct3 is
                    when RV32I_FN3_BEQ =>
                        if execute_rs1_dat = execute_rs2_dat then
                            execute_load_pc <= '1';
                        end if;
                    when RV32I_FN3_BNE =>
                        if execute_rs1_dat /= execute_rs2_dat then
                            execute_load_pc <= '1';
                        end if;
                    when RV32I_FN3_BLT =>
                        if signed(execute_rs1_dat) < signed(execute_rs2_dat) then
                            execute_load_pc <= '1';
                        end if;
                    when RV32I_FN3_BGE =>
                        if signed(execute_rs1_dat) >= signed(execute_rs2_dat) then
                            execute_load_pc <= '1';
                        end if;
                    when RV32I_FN3_BLTU =>
                        if unsigned(execute_rs1_dat) < unsigned(execute_rs2_dat) then
                            execute_load_pc <= '1';
                        end if;
                    when RV32I_FN3_BGEU =>
                        if unsigned(execute_rs1_dat) >= unsigned(execute_rs2_dat) then
                            execute_load_pc <= '1';
                        end if;
                    when others =>
                end case;
            when RV32I_OP_SYS =>
                if execute_funct3 = "000" then
                    case execute_immediate(11 downto 0) is
                        when CSR_FN12_ECALL => execute_ecall <= '1'; 
                        when CSR_FN12_EBREAK => execute_ebreak <= '1'; 
                        when CSR_FN12_MRET => execute_mret <= '1';
                        when others =>
                    end case;
                end if;
            when others =>
        end case;
    end process;

    process (execute_opcode, execute_rs1_dat, execute_rs2_dat, execute_immediate)
    begin
        execute_mem_adr <= (others => 'X');
        execute_mem_dat <= (others => 'X');
        case execute_opcode is
            when RV32I_OP_LOAD =>
                execute_mem_adr <= std_logic_vector(unsigned(execute_rs1_dat) + unsigned(execute_immediate));
            when RV32I_OP_STORE =>
                execute_mem_adr <= std_logic_vector(unsigned(execute_rs1_dat) + unsigned(execute_immediate));
                execute_mem_dat <= execute_rs2_dat;
            when others =>
        end case;
    end process;

    process (execute_opcode, execute_funct7, execute_funct3, execute_rs1_dat, execute_rs2_dat)
        variable mulhsu_res : std_logic_vector(65 downto 0);
    begin
        execute_mul <= (others => 'X');
        execute_div <= (others => 'X');
        execute_rem <= (others => 'X');
        mulhsu_res := (others => 'X');
        if execute_opcode = RV32I_OP_REG_REG and execute_funct7 = "0000001" then
            case execute_funct3 is
                when RV32M_FN3_MUL | RV32M_FN3_MULH =>
                    execute_mul <= std_logic_vector(signed(execute_rs1_dat) * signed(execute_rs2_dat));
                when RV32M_FN3_MULHSU =>
                    mulhsu_res := std_logic_vector(signed(execute_rs1_dat(execute_rs1_dat'left) & execute_rs1_dat) * signed('0' & execute_rs2_dat));
                    execute_mul <= mulhsu_res(63 downto 0);
                when RV32M_FN3_MULHU =>
                    execute_mul <= std_logic_vector(unsigned(execute_rs1_dat) * unsigned(execute_rs2_dat));
                when RV32M_FN3_DIV | RV32M_FN3_DIVU =>
                    if unsigned(execute_rs2_dat) /= 0 then
                        execute_div <=
                            std_logic_vector(
                                signed((execute_rs1_dat(31) and not execute_funct3(0)) & execute_rs1_dat) /
                                signed((execute_rs2_dat(31) and not execute_funct3(0)) & execute_rs2_dat));
                    else
                        execute_div <= (others => '1');
                    end if;
                when RV32M_FN3_REM | RV32M_FN3_REMU =>
                    if unsigned(execute_rs2_dat) /= 0 then
                        execute_rem <= std_logic_vector(
                                signed((execute_rs1_dat(31) and not execute_funct3(0)) & execute_rs1_dat) rem
                                signed((execute_rs2_dat(31) and not execute_funct3(0)) & execute_rs2_dat));
                    else
                        execute_div <= '0' & execute_rs1_dat;
                    end if;
                when others =>
            end case;
        end if;
    end process;

    process (execute_opcode, execute_funct3, execute_funct7, execute_alu, execute_mul, execute_div, execute_rem)
    begin
        execute_rd_dat <= (others => 'X');
        execute_rd_check_en <= '0';
        case execute_opcode is
            when RV32I_OP_LUI | RV32I_OP_AUIPC | RV32I_OP_JAL | RV32I_OP_JALR | RV32I_OP_REG_IMM =>
                execute_rd_dat <= execute_alu;
                execute_rd_check_en <= '1';
            when RV32I_OP_REG_REG =>
                execute_rd_check_en <= '1';
                case execute_funct7 is
                    when "0000000" | "0100000" =>
                        execute_rd_dat <= execute_alu;
                    when "0000001" =>
                        case execute_funct3 is
                            when RV32M_FN3_MUL =>
                                execute_rd_dat <= execute_mul(31 downto 0);
                            when RV32M_FN3_MULH | RV32M_FN3_MULHSU | RV32M_FN3_MULHU =>
                                execute_rd_dat <= execute_mul(63 downto 32);
                            when RV32M_FN3_DIV | RV32M_FN3_DIVU =>
                                execute_rd_dat <= execute_div(31 downto 0);
                            when RV32M_FN3_REM | RV32M_FN3_REMU =>
                                execute_rd_dat <= execute_rem(31 downto 0);
                            when others =>
                        end case;
                    when others =>
                end case;
            when others =>
        end case;
    end process;

    -- Memory stage
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if memory_enable_i = '1' then
                memory_opcode <= execute_opcode;
                memory_funct3 <= execute_funct3;
                memory_funct7 <= execute_funct7;
                memory_rd_adr <= execute_rd_adr;
                memory_rd_we <= execute_rd_we and execute_rd_check_en;
                memory_rd_dat <= execute_rd_dat;
                memory_mem_adr <= execute_mem_adr;
                memory_mem_dat <= execute_mem_dat;
                memory_load_pc <= execute_load_pc;
                memory_next_pc <= execute_next_pc;
                memory_ecall <= execute_ecall;
                memory_ebreak <= execute_ebreak;
                memory_mret <= execute_mret;
            end if;
        end if;
    end process;

    -- Writeback stage
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if writeback_enable_i = '1' then
                writeback_opcode <= memory_opcode;
                writeback_funct3 <= memory_funct3;
                writeback_rd_adr <= memory_rd_adr;
                writeback_rd_dat <= memory_rd_dat;
                writeback_rd_we <= memory_rd_we;
                writeback_rsp_adr <= memory_mem_adr(1 downto 0);
            end if;
        end if;
    end process;

    process (writeback_opcode, writeback_rd_dat, writeback_mem_rsp_dat)
    begin
        regfile_rd_dat <= (others => 'X');
        case writeback_opcode is
            when RV32I_OP_LUI | RV32I_OP_AUIPC | RV32I_OP_JAL | RV32I_OP_JALR | RV32I_OP_REG_IMM | RV32I_OP_REG_REG =>
                regfile_rd_dat <= writeback_rd_dat;
            when RV32I_OP_LOAD =>
                regfile_rd_dat <= writeback_mem_rsp_dat;
            when others =>
        end case;
    end process;

    regfile_rd_we <= writeback_rd_we and writeback_valid;
    regfile_rd_adr <= writeback_rd_adr;

    -- TODO fix exceptions entry/exit
    load_pc <= (memory_load_pc and memory_valid) or csr_exception_entry_i;-- or sync_exception_entry or exception_exit;
    target_pc <=
        csr_mtvec_i when csr_exception_entry_i = '1' else -- EXETERNAL INTERRUPTS
        memory_next_pc; -- JAL, JALR, BRANCH, ECALL, EBREAK, MRET

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            vhdl_assert(regfile_rd_we = '1' and not (regfile_rd_adr = regfile_rd_adr_i), "Writeback rd adr missmatch, model: " & to_hex_str(regfile_rd_adr) & " impl: " & to_hex_str(regfile_rd_adr_i) & " @ pc = " & to_hex_str(writeback_current_pc));
            vhdl_assert(regfile_rd_we = '1' and regfile_rd_we_i = '1' and not (regfile_rd_dat = regfile_rd_dat_i), "Writeback rd dat missmatch, model: " & to_hex_str(regfile_rd_dat) & " impl: " & to_hex_str(regfile_rd_dat_i) & " @ pc = " & to_hex_str(writeback_current_pc));
            vhdl_assert(load_pc = '1' and not (target_pc = fetch_target_pc_i), "Branching missmatch, model: " & to_hex_str(mem_cmd_adr) & " impl: " & to_hex_str(mem_cmd_adr_i) & " @ pc = " & to_hex_str(memory_current_pc));
            vhdl_assert(regfile_rd_we_i = '1' and not (or_reduct(regfile_rd_dat_i) = '0' or or_reduct(regfile_rd_dat_i) = '1'), "Writeback rd dat X prop, model: " & to_hex_str(regfile_rd_dat) & " impl: " & to_hex_str(regfile_rd_dat_i) & " @ pc = " & to_hex_str(writeback_current_pc), WARNING);
        end if;
    end process;

-- Memory asserts
    mem_cmd_adr <= execute_mem_adr;
    -- TODO
--    mem_cmd_vld <= '1' when execute_valid = '1' and fetch_load_pc_i = '0' and (execute_opcode = RV32I_OP_LOAD or execute_opcode = RV32I_OP_STORE) else '0';
    mem_cmd_vld <= '1' when execute_valid = '1' and (execute_opcode = RV32I_OP_LOAD or execute_opcode = RV32I_OP_STORE) else '0';
    mem_cmd_we  <= '1' when execute_opcode = RV32I_OP_STORE else '0';
    mem_rsp_vld <= '1' when writeback_valid = '1' and writeback_opcode = RV32I_OP_LOAD else '0';
    process (execute_funct3, execute_mem_dat)
    begin
        mem_cmd_dat <= (others => 'X');
        case execute_funct3 is
            when "000" =>
                mem_cmd_dat <= execute_mem_dat(7 downto 0) & execute_mem_dat(7 downto 0) & execute_mem_dat(7 downto 0) & execute_mem_dat(7 downto 0);
            when "001" =>
                mem_cmd_dat <= execute_mem_dat(15 downto 0) & execute_mem_dat(15 downto 0);
            when "010" =>
                mem_cmd_dat <= execute_mem_dat;
            when others =>
        end case;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            mem_rsp_dat <= (others => 'X');
            if mem_rsp_vld_i = '1' then
                case memory_funct3 is
                    when "000" | "100" =>
                        case mem_cmd_adr(1 downto 0) is
                            when "00" => mem_rsp_dat <= (31 downto 8 => (not writeback_funct3(2) and mem_rsp_dat_i(07))) & mem_rsp_dat_i(07 downto 00);
                            when "01" => mem_rsp_dat <= (31 downto 8 => (not writeback_funct3(2) and mem_rsp_dat_i(15))) & mem_rsp_dat_i(15 downto 08);
                            when "10" => mem_rsp_dat <= (31 downto 8 => (not writeback_funct3(2) and mem_rsp_dat_i(23))) & mem_rsp_dat_i(23 downto 16);
                            when "11" => mem_rsp_dat <= (31 downto 8 => (not writeback_funct3(2) and mem_rsp_dat_i(31))) & mem_rsp_dat_i(31 downto 24);
                            when others =>
                        end case;
                    when "001" | "101" =>
                        case mem_cmd_adr(1 downto 0) is
                            when "00" | "01" => mem_rsp_dat <= (31 downto 16 => (not writeback_funct3(2) and mem_rsp_dat_i(15))) & mem_rsp_dat_i(15 downto 00);
                            when "10" | "11" => mem_rsp_dat <= (31 downto 16 => (not writeback_funct3(2) and mem_rsp_dat_i(31))) & mem_rsp_dat_i(31 downto 16);
                            when others =>
                        end case;
                    when "010" =>
                        mem_rsp_dat <= mem_rsp_dat_i;
                    when others =>
                end case;
            end if;
        end if;
    end process;
    writeback_mem_rsp_dat <= mem_rsp_dat;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            vhdl_assert(mem_cmd_vld = '1' and not (mem_cmd_adr = mem_cmd_adr_i), "Memory access : address missmatch, model: " & to_hex_str(mem_cmd_adr) & " impl: " & to_hex_str(mem_cmd_adr_i) & " @ pc = " & to_hex_str(execute_current_pc));
            vhdl_assert((mem_cmd_vld and mem_cmd_we) = '1' and not (mem_cmd_dat = mem_cmd_dat_i), "Memory access : write data missmatch, model: " & to_hex_str(mem_cmd_dat) & " impl: " & to_hex_str(mem_cmd_dat_i) & " @ pc = " & to_hex_str(execute_current_pc));
            vhdl_assert((mem_cmd_vld and mem_cmd_we) = '1' and not (mem_cmd_vld_i and mem_cmd_we_i) = '1', "Memory access : write operation expected @ pc = " & to_hex_str(execute_current_pc));
            vhdl_assert((mem_cmd_vld and not mem_cmd_we) = '1' and not (mem_cmd_vld_i and not mem_cmd_we_i) = '1', "Memory access : read operation expected @ pc = " & to_hex_str(execute_current_pc));
        end if;
    end process;

-- Exceptions
    ecall <= memory_ecall;
    ebreak <= memory_ebreak;
    mret <= memory_mret;
    instruction_misaligned <= 
        '1' when memory_load_pc = '1' and memory_next_pc(1 downto 0) /= "00" and G_EXTENSION_ZICSR = TRUE and G_EXTENSION_C = FALSE else
        '1' when memory_load_pc = '1' and memory_next_pc(0) = '1' and G_EXTENSION_ZICSR = TRUE and G_EXTENSION_C = TRUE else
        '0';

    load_misaligned <= 
        '1' when memory_opcode = RV32I_OP_LOAD and (memory_funct3 = "001" or memory_funct3 = "101") and memory_mem_adr(0) = '1' and G_EXTENSION_ZICSR = TRUE else
        '1' when memory_opcode = RV32I_OP_LOAD and (memory_funct3 = "010" or memory_funct3 = "110") and memory_mem_adr(1 downto 0) /= "00" and G_EXTENSION_ZICSR = TRUE else
        '0';
    store_misaligned <= 
        '1' when memory_opcode = RV32I_OP_STORE and memory_funct3 = "001" and memory_mem_adr(0) = '1' and G_EXTENSION_ZICSR = TRUE else
        '1' when memory_opcode = RV32I_OP_STORE and memory_funct3 = "010" and memory_mem_adr(1 downto 0) /= "00" and G_EXTENSION_ZICSR = TRUE else
        '0';

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            d_async_exception_entry <= '0';
            d_sync_exception_entry <= '0';
        elsif rising_edge(clk_i) then
            d_async_exception_entry <= csr_exception_entry_i and csr_exception_async_i;
            d_sync_exception_entry <= csr_exception_entry_i and csr_exception_sync_i;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if csr_exception_entry_i = '1' then
                if ecall = '1' or ebreak = '1' or instruction_misaligned = '1' or load_misaligned = '1' or store_misaligned = '1' then
                    d_exception_pc <= memory_current_pc;
                else
                    d_exception_pc <= execute_current_pc;
                end if;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            vhdl_assert(d_sync_exception_entry = '1' and not (d_exception_pc = csr_mepc_i), "Sync exception PC not correct");
            vhdl_assert(d_async_exception_entry = '1' and d_sync_exception_entry = '0' and not ((std_logic_vector(unsigned(d_exception_pc))) = csr_mepc_i), "Async exception PC not correct");
            vhdl_assert(arst_i = '0' and fetch_enable_i = '1' and not (fetch_load_pc_i = '0' or fetch_load_pc_i = '1'), "fetch_load_pc_i = X");
        end if;
    end process;
end architecture rtl;
