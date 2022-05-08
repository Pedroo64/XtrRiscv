library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity execute is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        enable_i : in std_logic;
        valid_i : in std_logic;
        pc_i : in std_logic_vector(31 downto 0);
        opcode_i : in std_logic_vector(6 downto 0);
        immediate_i : in std_logic_vector(31 downto 0);
        rs1_adr_i : in std_logic_vector(4 downto 0);
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_adr_i : in std_logic_vector(4 downto 0);
        rs2_dat_i : in std_logic_vector(31 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_i : in std_logic;
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        rd_we_o : out std_logic;
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        writeback_valid_o : out std_logic;
        writeback_ready_i : in std_logic;
        pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        memory_valid_o : out std_logic;
        memory_address_o : out std_logic_vector(31 downto 0);
        memory_data_o : out std_logic_vector(31 downto 0);
        memory_we_o : out std_logic;
        memory_size_o : out std_logic_vector(1 downto 0);
        memory_ready_i : in std_logic;
        csr_valid_o : out std_logic;
        csr_address_o : out std_logic_vector(11 downto 0);
        csr_data_o : out std_logic_vector(31 downto 0);
        csr_ready_i : in std_logic;
        exception_valid_i : in std_logic;
        trap_vector_i : in std_logic_vector(31 downto 0);
        exception_pc_i : in std_logic_vector(31 downto 0);
        exception_pc_o : out std_logic_vector(31 downto 0);
        exception_taken_o : out std_logic;
        exception_exit_o : out std_logic;
        mret_o : out std_logic;
        ecall_o : out std_logic;
        ready_o : out std_logic
    );
end entity execute;

architecture rtl of execute is
    signal writeback_valid, memory_valid, csr_valid : std_logic;
    signal next_stage_ready : std_logic;
    signal next_pc, pc : std_logic_vector(31 downto 0);
    signal ecall, exception_taken, load_pc : std_logic;
begin
    
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if enable_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                rd_adr_o <= rd_adr_i;
                funct3_o <= funct3_i;
                funct7_o <= funct7_i;
                rd_we_o <= rd_we_i;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            writeback_valid <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                writeback_valid <= '0';
            else
                if enable_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    writeback_valid <= '0';
                    case opcode_i is
                        when RV32I_OP_LUI =>
                            rd_dat_o <= immediate_i;
                            writeback_valid <= '1';
                        when RV32I_OP_AUIPC =>
                            rd_dat_o <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                            writeback_valid <= '1';
                        when RV32I_OP_JAL =>
                            rd_dat_o <= std_logic_vector(unsigned(pc_i) + 4);
                            writeback_valid <= '1';
                        when RV32I_OP_JALR =>
                            rd_dat_o <= std_logic_vector(unsigned(pc_i) + 4);
                            writeback_valid <= '1';                            
                        when RV32I_OP_REG_IMM =>
                            writeback_valid <= '1';                            
                            case funct3_i is
                                when RV32I_FN3_ADD =>
                                    rd_dat_o <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                                when RV32I_FN3_SL =>
                                    rd_dat_o <= std_logic_vector(shift_left(unsigned(rs1_dat_i), to_integer(unsigned(immediate_i(4 downto 0)))));
                                when RV32I_FN3_SLT =>
                                    if signed(rs1_dat_i) < signed(immediate_i) then
                                        rd_dat_o <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                    else
                                        rd_dat_o <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                    end if;
                                when RV32I_FN3_SLTU =>
                                    if unsigned(rs1_dat_i) < unsigned(immediate_i) then
                                        rd_dat_o <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                    else
                                        rd_dat_o <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                    end if;
                                when RV32I_FN3_XOR =>
                                    rd_dat_o <= rs1_dat_i xor immediate_i;
                                when RV32I_FN3_SR =>
                                    if funct7_i(5) = '1' then
                                        rd_dat_o <= std_logic_vector(shift_right(signed(rs1_dat_i), to_integer(unsigned(immediate_i(4 downto 0)))));
                                    else
                                        rd_dat_o <= std_logic_vector(shift_right(unsigned(rs1_dat_i), to_integer(unsigned(immediate_i(4 downto 0)))));
                                    end if;
                                when RV32I_FN3_OR =>
                                    rd_dat_o <= rs1_dat_i or immediate_i;
                                when RV32I_FN3_AND =>
                                    rd_dat_o <= rs1_dat_i and immediate_i;
                                when others =>
                            end case;
                        when RV32I_OP_REG_REG =>
                            writeback_valid <= '1';
                            case funct3_i is
                                when RV32I_FN3_ADD =>
                                    if funct7_i(5) = '1' then
                                        rd_dat_o <= std_logic_vector(unsigned(rs1_dat_i) - unsigned(rs2_dat_i));
                                    else
                                        rd_dat_o <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(rs2_dat_i));
                                    end if;
                                when RV32I_FN3_SL =>
                                    rd_dat_o <= std_logic_vector(shift_left(unsigned(rs1_dat_i), to_integer(unsigned(rs2_dat_i(4 downto 0)))));
                                when RV32I_FN3_SLT =>
                                    if signed(rs1_dat_i) < signed(rs2_dat_i) then
                                        rd_dat_o <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                    else
                                        rd_dat_o <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                    end if;
                                when RV32I_FN3_SLTU =>
                                    if unsigned(rs1_dat_i) < unsigned(rs2_dat_i) then
                                        rd_dat_o <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                    else
                                        rd_dat_o <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                    end if;
                                when RV32I_FN3_XOR =>
                                    rd_dat_o <= rs1_dat_i xor rs2_dat_i;
                                when RV32I_FN3_SR =>
                                    if funct7_i(5) = '1' then
                                        rd_dat_o <= std_logic_vector(shift_right(signed(rs1_dat_i), to_integer(unsigned(rs2_dat_i(4 downto 0)))));
                                    else
                                        rd_dat_o <= std_logic_vector(shift_right(unsigned(rs1_dat_i), to_integer(unsigned(rs2_dat_i(4 downto 0)))));
                                    end if;
                                when RV32I_FN3_OR =>
                                    rd_dat_o <= rs1_dat_i or rs2_dat_i;

                                when RV32I_FN3_AND =>
                                    rd_dat_o <= rs1_dat_i and rs2_dat_i;
                                when others =>
                            end case;
                        when others =>
                    end case;
                elsif writeback_valid = '1' and next_stage_ready = '1' then
                    writeback_valid <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            load_pc <= '0';
            ecall <= '0';
            mret_o <= '0';
            exception_taken <= '0';
            exception_exit_o <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                load_pc <= '0';
                ecall <= '0';
                mret_o <= '0';
                exception_taken <= '0';
                exception_exit_o <= '0';
            else
                load_pc <= '0';
                ecall <= '0';
                mret_o <= '0';
                exception_taken <= '0';
                exception_exit_o <= '0';
 --               if exception_valid_i = '1' then
 --                   pc_o <= trap_vector_i;
 --                   load_pc_o <= '1';
 --                   exception_taken_o <= '1';
 --                   saved_pc <= pc_o;
 --               end if;
                if enable_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    pc <= pc_i;
                    case opcode_i is
                        when RV32I_OP_JAL =>
                            next_pc <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                            load_pc <= '1';
                        when RV32I_OP_JALR =>
                            next_pc <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                            load_pc <= '1';
                        when RV32I_OP_BRANCH =>
                            next_pc <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                            case funct3_i is
                                when RV32I_FN3_BEQ =>
                                    if rs1_dat_i = rs2_dat_i then
                                        load_pc <= '1';
                                    end if;
                                when RV32I_FN3_BNE =>
                                    if rs1_dat_i /= rs2_dat_i then
                                        load_pc <= '1';
                                    end if;
                                when RV32I_FN3_BLT =>
                                    if signed(rs1_dat_i) < signed(rs2_dat_i) then
                                        load_pc <= '1';
                                    end if;
                                when RV32I_FN3_BGE =>
                                    if signed(rs1_dat_i) >= signed(rs2_dat_i) then
                                        load_pc <= '1';
                                    end if;
                                when RV32I_FN3_BLTU =>
                                    if unsigned(rs1_dat_i) < unsigned(rs2_dat_i) then
                                        load_pc <= '1';
                                    end if;
                                when RV32I_FN3_BGEU =>
                                    if unsigned(rs1_dat_i) >= unsigned(rs2_dat_i) then
                                        load_pc <= '1';
                                    end if;
                                when others =>
                            end case;
                        when RV32I_OP_SYS =>
                            if funct3_i = RV32I_FN3_TRAP then
                                case immediate_i(11 downto 0) is
                                    when RV32I_SYS_MRET =>
                                        mret_o <= '1';
                                        load_pc <= '1';
                                        next_pc <= exception_pc_i;
                                        exception_exit_o <= '1';
                                    when RV32I_SYS_ECALL =>
                                        ecall <= '1';
                                        exception_taken <= '1';
                                        --saved_pc <= std_logic_vector(unsigned(pc_i) + 4);
                                        --exception_pc_o <= pc_i;
                                    when others =>
                                end case;
                            end if;
                        when others =>
                    end case;
                    if exception_valid_i = '1' and opcode_i /= RV32I_OP_SYS then
                        exception_taken <= '1';
                        --saved_pc <= std_logic_vector(unsigned(pc_i) + 4);
                        --exception_pc_o <= std_logic_vector(unsigned(pc_i) + 4);
                    end if;
                end if;
--                if exception_taken = '1' and load_pc = '1' then
--                    exception_pc_o <= next_pc;
--                    --saved_pc <= next_pc;
--                end if;
            end if;
        end if;
    end process;

    exception_pc_o <= 
        next_pc when load_pc = '1' else 
        pc when ecall = '1' else
        std_logic_vector(unsigned(pc) + 4);

    pc_o <= 
        trap_vector_i when exception_taken = '1' else
        next_pc;
    load_pc_o <= load_pc or exception_taken;
    exception_taken_o <= exception_taken;
    ecall_o <= ecall;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            memory_valid <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                memory_valid <= '0';
            else
                if enable_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    memory_address_o <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                    memory_data_o <= rs2_dat_i;
                    memory_valid <= '0';
                    memory_we_o <= '0';
                    memory_size_o <= funct3_i(1 downto 0);
                    case opcode_i is
                        when RV32I_OP_LOAD =>
                            memory_valid <= '1';
                            memory_we_o <= '0';
                        when RV32I_OP_STORE =>
                            memory_valid  <= '1';
                            memory_we_o <= '1';
                        when others =>
                    end case;
                elsif memory_valid = '1' and next_stage_ready = '1' then
                    memory_valid <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            csr_valid <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                csr_valid <= '0';
            else
                if enable_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    csr_address_o <= immediate_i(11 downto 0);
                    csr_valid <= '0';
                    if opcode_i = RV32I_OP_SYS then
                        csr_valid <= '1';
                        case funct3_i is
                            when RV32I_FN3_CSRRW =>
                                csr_data_o <= rs1_dat_i;
                            when RV32I_FN3_CSRRS =>
                                csr_data_o <= rs1_dat_i;
                            when RV32I_FN3_CSRRC =>
                                csr_data_o <= not rs1_dat_i;
                            when RV32I_FN3_CSRRWI =>
                                csr_data_o(31 downto 5) <= (others => '0');
                                csr_data_o(4 downto 0) <= rs1_adr_i;
                            when RV32I_FN3_CSRRSI =>
                                csr_data_o(31 downto 5) <= (others => '0');
                                csr_data_o(4 downto 0) <= rs1_adr_i;
                            when RV32I_FN3_CSRRCI =>
                                csr_data_o(31 downto 5) <= (others => '1');
                                csr_data_o(4 downto 0) <= not rs1_adr_i;                                                        
                            when others =>
                                csr_valid <= '0';
                        end case;
                    end if;
                elsif valid_i = '1' and next_stage_ready = '1' then
                    csr_valid <= '0';
                end if;
            end if;
        end if;
    end process;

    next_stage_ready <= 
        '0' when writeback_valid = '1' and writeback_ready_i = '0' else
        '0' when memory_valid = '1' and memory_ready_i = '0' else
        '0' when csr_valid = '1' and csr_ready_i = '0' else
        '1';
    ready_o <= enable_i and next_stage_ready;

    writeback_valid_o <= writeback_valid;
    memory_valid_o <= memory_valid;
    csr_valid_o <= csr_valid;
    
end architecture rtl;