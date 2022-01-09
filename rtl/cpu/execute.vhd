library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity execute is
    port (
        arst_i        : in std_logic;
        clk_i         : in std_logic;
        srst_i        : in std_logic;
        en_i          : in std_logic;
        vld_i         : in std_logic;
        mem_vld_i     : in std_logic;
        pc_i          : in std_logic_vector(31 downto 0);
        opcode_i      : in std_logic_vector(6 downto 0);
        rs1_dat_i     : in std_logic_vector(31 downto 0);
        rs2_dat_i     : in std_logic_vector(31 downto 0);
        immediate_i   : in std_logic_vector(31 downto 0);
        funct3_i      : in std_logic_vector(2 downto 0);
        funct7_i      : in std_logic_vector(6 downto 0);
        rd_adr_i      : in std_logic_vector(4 downto 0);
        rd_we_o       : out std_logic;
        rd_adr_o      : out std_logic_vector(4 downto 0);
        rd_dat_o      : out std_logic_vector(31 downto 0);
        load_pc_o     : out std_logic;
        pc_o          : out std_logic_vector(31 downto 0);
        mem_rd_adr_o  : out std_logic_vector(4 downto 0);
        mem_cmd_adr_o : out std_logic_vector(31 downto 0);
        mem_cmd_vld_o : out std_logic;
        mem_cmd_we_o  : out std_logic;
        mem_cmd_dat_o : out std_logic_vector(31 downto 0);
        mem_cmd_siz_o : out std_logic_vector(1 downto 0);
        mem_rdy_i     : in std_logic;
        wb_rdy_i      : in std_logic;
        rdy_o         : out std_logic
    );
end entity execute;

architecture rtl of execute is
    signal mem_rdy, wb_rdy, rdy        : std_logic;
    signal rd_we, load_pc, mem_cmd_vld : std_logic;
begin

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            rd_we   <= '0';
            load_pc <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                rd_we   <= '0';
                load_pc <= '0';
            else
                if en_i = '1' and vld_i = '1' and mem_vld_i = '0' then
                    if wb_rdy = '1' then
                        rd_adr_o <= rd_adr_i;
                        rd_we    <= '0';
                        load_pc  <= '0';
                        case opcode_i is
                            when RV32I_OP_LUI =>
                                rd_dat_o <= immediate_i;
                                rd_we    <= '1';
                            when RV32I_OP_AUIPC =>
                                --pc_o     <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                                --load_pc  <= '1';
                                rd_dat_o <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                                rd_we    <= '1';
                            when RV32I_OP_JAL =>
                                pc_o     <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
                                load_pc  <= '1';
                                rd_dat_o <= std_logic_vector(unsigned(pc_i) + 4);
                                rd_we    <= '1';

                            when RV32I_OP_JALR =>
                                pc_o     <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                                load_pc  <= '1';
                                rd_dat_o <= std_logic_vector(unsigned(pc_i) + 4);
                                rd_we    <= '1';

                            when RV32I_OP_BRANCH =>
                                pc_o <= std_logic_vector(unsigned(pc_i) + unsigned(immediate_i));
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
                                --                        when RV32I_OP_LOAD =>
                                --                            mem_cmd_vld <= '1';
                                --                            mem_cmd_we_o <= '0';
                                --                            rd_we <= '1';
                                --                        when RV32I_OP_STORE =>
                                --                            mem_cmd_vld <= '1';
                                --                            mem_cmd_we_o <= '1';
                                --
                            when RV32I_OP_REG_IMM =>
                                rd_we <= '1';
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
                                rd_we <= '1';
                                case funct3_i is
                                    when RV32I_FN3_ADD =>
                                        rd_dat_o <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(rs2_dat_i));
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
                    end if;
                elsif (rd_we = '1' or load_pc = '1') and wb_rdy = '1' then
                    rd_we   <= '0';
                    load_pc <= '0';
                end if;
            end if;
        end if;
    end process;

    process (clk_i, arst_i)
    begin
        if arst_i = '1' then
            mem_cmd_vld  <= '0';
            mem_cmd_we_o <= '0';
        elsif rising_edge(clk_i) then
            if srst_i = '1' then
                mem_cmd_vld  <= '0';
                mem_cmd_we_o <= '0';
            else
                if en_i = '1' and vld_i = '1' and mem_vld_i = '1' and mem_rdy = '1' then
                    --if mem_rdy = '1' then
                    mem_rd_adr_o  <= rd_adr_i;
                    mem_cmd_adr_o <= std_logic_vector(unsigned(rs1_dat_i) + unsigned(immediate_i));
                    mem_cmd_siz_o <= funct3_i(1 downto 0);
                    mem_cmd_vld   <= '0';
                    mem_cmd_we_o  <= '0';
                    mem_cmd_dat_o <= rs2_dat_i;
                    case opcode_i is
                        when RV32I_OP_LOAD =>
                            mem_cmd_vld  <= '1';
                            mem_cmd_we_o <= '0';
                        when RV32I_OP_STORE =>
                            mem_cmd_vld  <= '1';
                            mem_cmd_we_o <= '1';

                        when others =>
                    end case;
                    --end if;
                elsif mem_cmd_vld = '1' and mem_rdy = '1' then
                    mem_cmd_vld  <= '0';
                    mem_cmd_we_o <= '0';
                end if;
            end if;
        end if;
    end process;

    mem_rdy <=
        '0' when mem_cmd_vld = '1' and mem_rdy_i = '0' else
        '1';
    wb_rdy <=
        '0' when rd_we = '1' and wb_rdy_i = '0' else
        '0' when load_pc = '1' and wb_rdy_i = '0' else
        '1';

    rd_we_o       <= rd_we;
    load_pc_o     <= load_pc;
    mem_cmd_vld_o <= mem_cmd_vld;

    rdy <=
        mem_rdy when mem_vld_i = '1' else
        wb_rdy;

    rdy_o <= rdy and en_i;
end architecture rtl;