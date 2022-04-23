library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;


entity execute is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        srst_i : in std_logic;
        en_i : in std_logic;
        valid_i : in std_logic;
        hold_i : in std_logic;
        pc_i : in std_logic_vector(31 downto 0);
        opcode_i : in std_logic_vector(6 downto 0);
        rs1_dat_i : in std_logic_vector(31 downto 0);
        rs2_dat_i : in std_logic_vector(31 downto 0);
        immediate_i : in std_logic_vector(31 downto 0);
        funct3_i : in std_logic_vector(2 downto 0);
        funct7_i : in std_logic_vector(6 downto 0);
        csr_zimm_i : in std_logic_vector(4 downto 0);
        rd_adr_i : in std_logic_vector(4 downto 0);
        rd_we_o : out std_logic;
        rd_adr_o : out std_logic_vector(4 downto 0);
        rd_dat_o : out std_logic_vector(31 downto 0);
        funct3_o : out std_logic_vector(2 downto 0);
        funct7_o : out std_logic_vector(6 downto 0);
        pc_o : out std_logic_vector(31 downto 0);
        load_pc_o : out std_logic;
        valid_o : out std_logic;
        write_back_valid_o : out std_logic;
        write_back_rd_adr_o : out std_logic_vector(4 downto 0);
        write_back_rd_dat_o : out std_logic_vector(31 downto 0);
        write_back_rd_we_o : out std_logic;
        write_back_ready_i : in std_logic;
        memory_valid_o : out std_logic;
        memory_rd_adr_o : out std_logic_vector(4 downto 0);
        memory_address_o : out std_logic_vector(31 downto 0);
        memory_data_o : out std_logic_vector(31 downto 0);
        memory_size_o : out std_logic_vector(1 downto 0);
        memory_we_o : out std_logic;
        memory_ready_i : in std_logic;
        csr_valid_o : out std_logic;
        csr_rd_adr_o : out std_logic_vector(4 downto 0);
        csr_address_o : out std_logic_vector(11 downto 0);
        csr_data_o : out std_logic_vector(31 downto 0);
        csr_ready_i : in std_logic;
        ecall_o : out std_logic;
        mret_o : out std_logic;
        ready_o : out std_logic
    );
end entity execute;

architecture rtl of execute is
    signal valid, next_stage_ready : std_logic;
    signal write_back_valid, memory_valid, csr_valid : std_logic;
    signal write_back_rd_we : std_logic;
    signal write_back_rd_dat : std_logic_vector(31 downto 0);
    signal write_back_rd_adr : std_logic_vector(4 downto 0);
    signal memory_rd_we : std_logic;
    signal memory_rd_dat : std_logic_vector(31 downto 0);
    signal memory_rd_adr : std_logic_vector(4 downto 0);
    signal memory_address : std_logic_vector(31 downto 0);
    signal memory_size : std_logic_vector(1 downto 0);
    signal csr_rd_we : std_logic;
    signal csr_rd_adr : std_logic_vector(4 downto 0);
    signal csr_rd_dat : std_logic_vector(31 downto 0);
    signal csr_address : std_logic_vector(11 downto 0);
    signal sys_call : std_logic;
begin
    
    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            write_back_rd_we <= '0';
            load_pc_o <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                write_back_rd_we <= '0';
                load_pc_o <= '0';
            else
                load_pc_o <= '0';
                if en_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    pc_o <= std_logic_vector(unsigned(pc_i) + 4);
                    funct3_o <= funct3_i;
                    funct7_o <= funct7_i;
                end if;
                if en_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    if true then
                        write_back_rd_adr <= rd_adr_i;
                        write_back_rd_we <= '0';
                        case opcode_i is
                            when RV32I_OP_LUI =>
                                write_back_rd_dat <= immediate_i;
                                write_back_rd_we <= '1';
                            when RV32I_OP_AUIPC =>
                                write_back_rd_dat <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                                write_back_rd_we <= '1';
                            when RV32I_OP_JAL =>
                                pc_o <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                                load_pc_o <= '1';
                                write_back_rd_dat <= std_logic_vector(unsigned(pc_i) + 4);
                                write_back_rd_we <= '1';

                            when RV32I_OP_JALR =>
                                pc_o <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                                load_pc_o <= '1';
                                write_back_rd_dat <= std_logic_vector(unsigned(pc_i) + 4);
                                write_back_rd_we <= '1';

                            when RV32I_OP_BRANCH =>
                                pc_o <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                                case funct3_i is
                                    when RV32I_FN3_BEQ =>
                                        if rs1_dat_i = rs2_dat_i then
                                            load_pc_o <= '1';
                                        end if;
                                    when RV32I_FN3_BNE =>
                                        if rs1_dat_i /= rs2_dat_i then
                                            load_pc_o <= '1';
                                        end if;
                                    when RV32I_FN3_BLT =>
                                        if signed(rs1_dat_i) < signed(rs2_dat_i) then
                                            load_pc_o <= '1';
                                        end if;
                                    when RV32I_FN3_BGE =>
                                        if signed(rs1_dat_i) >= signed(rs2_dat_i) then
                                            load_pc_o <= '1';
                                        end if;
                                    when RV32I_FN3_BLTU =>
                                        if unsigned(rs1_dat_i) < unsigned(rs2_dat_i) then
                                            load_pc_o <= '1';
                                        end if;
                                    when RV32I_FN3_BGEU =>
                                        if unsigned(rs1_dat_i) >= unsigned(rs2_dat_i) then
                                            load_pc_o <= '1';
                                        end if;
                                    when others =>
                                end case;
                            when RV32I_OP_REG_IMM =>
                                write_back_rd_we <= '1';
                                case funct3_i is
                                    when RV32I_FN3_ADD =>
                                        write_back_rd_dat <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                                    
                                    when RV32I_FN3_SL =>
                                        write_back_rd_dat <= std_logic_vector(shift_left(unsigned(rs1_dat_i), to_integer(unsigned(immediate_i(4 downto 0)))));

                                    when RV32I_FN3_SLT =>
                                        if signed(rs1_dat_i) < signed(immediate_i) then
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                        else
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                        end if;

                                    when RV32I_FN3_SLTU =>
                                        if unsigned(rs1_dat_i) < unsigned(immediate_i) then
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                        else
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                        end if;
                                    when RV32I_FN3_XOR =>
                                        write_back_rd_dat <= rs1_dat_i xor immediate_i;
                                    when RV32I_FN3_SR =>
                                        if funct7_i(5) = '1' then
                                            write_back_rd_dat <= std_logic_vector(shift_right(signed(rs1_dat_i), to_integer(unsigned(immediate_i(4 downto 0)))));
                                        else
                                            write_back_rd_dat <= std_logic_vector(shift_right(unsigned(rs1_dat_i), to_integer(unsigned(immediate_i(4 downto 0)))));
                                        end if;
                                    when RV32I_FN3_OR =>
                                        write_back_rd_dat <= rs1_dat_i or immediate_i;

                                    when RV32I_FN3_AND =>
                                        write_back_rd_dat <= rs1_dat_i and immediate_i;

                                    when others =>
                                end case;
                            when RV32I_OP_REG_REG =>
                                write_back_rd_we <= '1';
                                case funct3_i is
                                    when RV32I_FN3_ADD =>
                                        if funct7_i(5) = '1' then
                                            write_back_rd_dat <= std_logic_vector(unsigned(rs1_dat_i) - unsigned(rs2_dat_i));
                                        else
                                            write_back_rd_dat <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(rs2_dat_i));
                                        end if;
                                    when RV32I_FN3_SL =>
                                        write_back_rd_dat <= std_logic_vector(shift_left(unsigned(rs1_dat_i), to_integer(unsigned(rs2_dat_i(4 downto 0)))));
                                    when RV32I_FN3_SLT =>
                                        if signed(rs1_dat_i) < signed(rs2_dat_i) then
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                        else
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                        end if;
                                    when RV32I_FN3_SLTU =>
                                        if unsigned(rs1_dat_i) < unsigned(rs2_dat_i) then
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(1, rd_dat_o'length));
                                        else
                                            write_back_rd_dat <= std_logic_vector(to_unsigned(0, rd_dat_o'length));
                                        end if;
                                    when RV32I_FN3_XOR =>
                                        write_back_rd_dat <= rs1_dat_i xor rs2_dat_i;
                                    when RV32I_FN3_SR =>
                                        if funct7_i(5) = '1' then
                                            write_back_rd_dat <= std_logic_vector(shift_right(signed(rs1_dat_i), to_integer(unsigned(rs2_dat_i(4 downto 0)))));
                                        else
                                            write_back_rd_dat <= std_logic_vector(shift_right(unsigned(rs1_dat_i), to_integer(unsigned(rs2_dat_i(4 downto 0)))));
                                        end if;
                                    when RV32I_FN3_OR =>
                                        write_back_rd_dat <= rs1_dat_i or rs2_dat_i;

                                    when RV32I_FN3_AND =>
                                        write_back_rd_dat <= rs1_dat_i and rs2_dat_i;
                                    when others =>
                                end case;
                            when others =>
                        end case;
                    end if;
                elsif write_back_rd_we = '1' and next_stage_ready = '1' then
                    write_back_rd_we <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            memory_valid <= '0';
            memory_rd_we <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                memory_valid <= '0';
                memory_rd_we <= '0';
            else
                if en_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    --if mem_rdy = '1' then
                    memory_rd_adr <= rd_adr_i;
                    memory_address <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                    memory_size <= funct3_i(1 downto 0);
                    memory_valid <= '0';
                    memory_rd_we <= '0';
                    memory_data_o <= rs2_dat_i;
                    case opcode_i is
                        when RV32I_OP_LOAD =>
                            memory_valid <= '1';
                            memory_rd_we <= '1';

                        when RV32I_OP_STORE =>
                            memory_valid  <= '1';
                            memory_rd_we <= '0';

                        when others =>
                    end case;
                    --end if;
                elsif memory_valid = '1' and next_stage_ready = '1' then
                    memory_valid <= '0';
                    memory_rd_we <= '0';
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
                if en_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    csr_address <= immediate_i(11 downto 0);
                    csr_rd_adr <= rd_adr_i;
                    csr_valid <= '0';
                    csr_rd_we <= '0';
                    if opcode_i = RV32I_OP_SYS then
                        csr_valid <= '1';
                        csr_rd_we <= '1';
                        case funct3_i is
                            when RV32I_FN3_CSRRW =>
                                csr_rd_dat <= rs1_dat_i;
                            when RV32I_FN3_CSRRS =>
                                csr_rd_dat <= rs1_dat_i;
                            when RV32I_FN3_CSRRC =>
                                csr_rd_dat <= not rs1_dat_i;
                            when RV32I_FN3_CSRRWI =>
                                csr_rd_dat(31 downto 5) <= (others => '0');
                                csr_rd_dat(4 downto 0) <= csr_zimm_i;
                            when RV32I_FN3_CSRRSI =>
                                csr_rd_dat(31 downto 5) <= (others => '0');
                                csr_rd_dat(4 downto 0) <= csr_zimm_i;
                            when RV32I_FN3_CSRRCI =>
                                csr_rd_dat(31 downto 5) <= (others => '1');
                                csr_rd_dat(4 downto 0) <= not csr_zimm_i;                                                        
                            when others =>
                                csr_valid <= '0';
                                csr_rd_we <= '0';
                        end case;
                    end if;
                elsif valid_i = '1' and next_stage_ready = '1' then
                    csr_valid <= '0';
                    csr_rd_we <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mret_o <= '0';
            ecall_o <= '0';
            sys_call <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mret_o <= '0';
                ecall_o <= '0';
                sys_call <= '0';
            else
                mret_o <= '0';
                ecall_o <= '0';
                sys_call <= '0';
                if en_i = '1' and valid_i = '1' and next_stage_ready = '1' then
                    if opcode_i = RV32I_OP_SYS then
                        if funct3_i = RV32I_FN3_TRAP then
                            case immediate_i(11 downto 0) is
                                when RV32I_SYS_MRET =>
                                    mret_o <= '1';
                                    sys_call <= '1';
                                when RV32I_SYS_ECALL =>
                                    ecall_o <= '1';
                                    sys_call <= '1';
                                when others =>
                            end case;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    write_back_valid <= write_back_rd_we;

    valid_o <= (write_back_valid or memory_valid or csr_valid or sys_call) and next_stage_ready;

    next_stage_ready <= 
        '0' when hold_i = '1' else
        '0' when write_back_valid = '1' and write_back_ready_i = '0' else
        '0' when memory_valid = '1' and memory_ready_i = '0' else
        '0' when csr_valid = '1' and csr_ready_i = '0' else
        '1';

    rd_we_o <= write_back_rd_we or memory_rd_we or (csr_rd_we and csr_valid);
    rd_dat_o <= 
        write_back_rd_dat;-- when write_back_rd_we = '1' else
--        memory_rd_dat when memory_rd_we = '1' else
--        csr_rd_dat;

    rd_adr_o <= 
        write_back_rd_adr when write_back_rd_we = '1' else
        memory_rd_adr when memory_rd_we = '1' else
        csr_rd_adr;

    write_back_valid_o <= write_back_valid and not hold_i;
    write_back_rd_adr_o <= write_back_rd_adr;
    write_back_rd_dat_o <= write_back_rd_dat;
    write_back_rd_we_o <= write_back_rd_we and not hold_i;

    memory_valid_o <= memory_valid and not hold_i;
    memory_address_o <= memory_address;
--    memory_data_o <= memory_rd_dat;
    memory_we_o <= not memory_rd_we and not hold_i;
    memory_rd_adr_o <= memory_rd_adr;
    memory_size_o <= memory_size;

    csr_valid_o <= csr_valid and not hold_i;
    csr_address_o <= csr_address; 
    csr_data_o <= csr_rd_dat;
    csr_rd_adr_o <= csr_rd_adr;
    
    ready_o <= en_i and next_stage_ready;

    
end architecture rtl;