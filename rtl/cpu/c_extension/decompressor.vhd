library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity decompressor is
    generic (
        G_CATCH_ILLEGAL : boolean := FALSE
    );
    port (
        instr_i : in std_logic_vector(15 downto 0);
        instr_o : out std_logic_vector(31 downto 0)
    );
end entity decompressor;

architecture rtl of decompressor is
    signal ci : std_logic_vector(15 downto 0);
    signal ci_op : std_logic_vector(4 downto 0);
    signal instr : std_logic_vector(31 downto 0);
    signal rs1_zero, rs2_zero : std_logic;
    signal illegal : std_logic;
begin
    ci <= instr_i;
    ci_op <= ci(1 downto 0) & ci(15 downto 13);

    rs1_zero <= '1' when unsigned(ci(11 downto 7)) = 0 else '0';
    rs2_zero <= '1' when unsigned(ci(6 downto 2)) = 0 else '0';

    process (ci_op, ci, rs1_zero, rs2_zero)
    begin
        instr <= (others => 'X');
        illegal <= '0';
        case ci_op is
            when "00000" => -- C.ADDI4SPN
                instr(31 downto 30) <= (others => '0');
                instr(29 downto 26) <= ci(10 downto 7);
                instr(25 downto 24) <= ci(12 downto 11);
                instr(23) <= ci(5);
                instr(22) <= ci(6);
                instr(21 downto 20) <= (others => '0');
                instr(19 downto 15) <= "00010"; -- SP
                instr(14 downto 12) <= "000";
                instr(11 downto 7) <= "01" & ci(4 downto 2); -- c.rd
                instr(6 downto 0) <= RV32I_OP_REG_IMM;
            when "00010" => -- C.LW
                instr(31 downto 27) <= (others => '0'); -- imm 11-7
                instr(26 downto 22) <= ci(5) & ci(12) & ci(11) & ci(10) & ci(6); -- imm 6-2
                instr(21 downto 20) <= (others => '0'); -- imm 1-0
                instr(19 downto 15) <= "01" & ci(9 downto 7);
                instr(14 downto 12) <= "010";
                instr(11 downto 7) <= "01" & ci(4 downto 2); -- c.rd
                instr(6 downto 0) <= RV32I_OP_LOAD;
            when "00110" => -- C.SW
                instr(31 downto 27) <= (others => '0'); -- imm 11 - 7
                instr(26 downto 25) <= ci(5) & ci(12); -- imm 6 - 5
                instr(24 downto 20) <= "01" & ci(4 downto 2); -- c.rs2
                instr(19 downto 15) <= "01" & ci(9 downto 7); -- c.rs1
                instr(14 downto 12) <= "010";
                instr(11 downto 7) <= ci(11 downto 10) & ci(6) & "00"; -- imm 4 - 0
                instr(6 downto 0) <= RV32I_OP_STORE;
            when "01000" => -- C.ADDI
                instr(31 downto 25) <= (others => ci(12));
                instr(24 downto 20) <= ci(6 downto 2);
                instr(19 downto 15) <= ci(11 downto 7); -- rs1
                instr(14 downto 12) <= "000";
                instr(11 downto 7) <= ci(11 downto 7); -- rd
                instr(6 downto 0) <= RV32I_OP_REG_IMM;
            when "01001" => -- C.JAL
                instr(31) <= ci(12); -- imm 20
                instr(30) <= ci(8); -- imm 10
                instr(29 downto 28) <= ci(10 downto 9); -- imm 9-8
                instr(27) <= ci(6); -- imm 7
                instr(26) <= ci(7); -- imm 6
                instr(25) <= ci(2); -- imm 5
                instr(24) <= ci(11); -- imm 4
                instr(23 downto 21) <= ci(5 downto 3); -- imm 3-1
                instr(20) <= ci(12); -- imm 11
                instr(19 downto 12) <= (others => ci(12)); -- imm 19-12
                instr(11 downto 7) <= "00001";
                instr(6 downto 0) <= RV32I_OP_JAL;
            when "01010" => -- C.LI
                instr(31 downto 25) <= (others => ci(12));
                instr(24 downto 20) <= ci(6 downto 2);
                instr(19 downto 15) <= (others => '0');
                instr(14 downto 12) <= "000";
                instr(11 downto 7) <= ci(11 downto 7);
                instr(6 downto 0) <= RV32I_OP_REG_IMM;
            when "01011" => -- C.ADDI16SP OR C.LUI
                if unsigned(ci(11 downto 7)) = 2 then -- C.ADDI16SP
                    instr(31 downto 29) <= (others => ci(12));
                    instr(28 downto 24) <= ci(4 downto 3) & ci(5) & ci(2) & ci(6);
                    instr(23 downto 20) <= (others => '0'); -- IMM
                    instr(19 downto 15) <= ci(11 downto 7); -- RS1
                    instr(14 downto 12) <= "000"; -- FUNCT3
                    instr(11 downto 7) <= ci(11 downto 7); -- RD
                    instr(6 downto 0) <= RV32I_OP_REG_IMM; -- OPCODE
                else                                   -- C.LUI
                    instr(31 downto 17) <= (others => ci(12));
                    instr(16 downto 12) <= ci(6 downto 2); -- IMM
                    instr(11 downto 7) <= ci(11 downto 7); -- RD
                    instr(6 downto 0) <= RV32I_OP_LUI; -- OPCODE
                end if;
            when "01100" =>
                instr(19 downto 15) <= "01" & ci(9 downto 7); -- C.RS1
                instr(11 downto 07) <= "01" & ci(9 downto 7); -- C.RD
                case ci(11 downto 10) is
                    when "00" => -- C.SRLI
                        instr(31 downto 20) <= (31 downto 25 => '0') & ci(6 downto 2);
                        instr(14 downto 12) <= "101";
                        instr(6 downto 0) <= RV32I_OP_REG_IMM;
                    when "01" => -- C.SRAI
                        instr(31 downto 20) <= "01" & (29 downto 25 => '0') & ci(6 downto 2);
                        instr(14 downto 12) <= "101";
                        instr(6 downto 0) <= RV32I_OP_REG_IMM;
                    when "10" => -- C.ANDI
                        instr(31 downto 20) <= (31 downto 25 => ci(12)) & ci(6 downto 2);
                        instr(14 downto 12) <= "111";
                        instr(6 downto 0) <= RV32I_OP_REG_IMM;
                    when "11" =>
                        instr(24 downto 20) <= "01" & ci(4 downto 2); -- C.RS2
                        instr(6 downto 0) <= RV32I_OP_REG_REG;
                        instr(31 downto 25) <= '0' & not (ci(6) or ci(5)) & (29 downto 25 => '0');
                        case ci(6 downto 5) is
                            when "00" => instr(14 downto 12) <= "000";
                            when "01" => instr(14 downto 12) <= "100";
                            when "10" => instr(14 downto 12) <= "110";
                            when "11" => instr(14 downto 12) <= "111";
                            when others =>
                        end case;
                    when others =>
                end case;
                illegal <= ci(12);
            when "01101" => -- C.J
                instr(31) <= ci(12); -- imm 20
                instr(30) <= ci(8); -- imm 10
                instr(29 downto 28) <= ci(10 downto 9); -- imm 9-8
                instr(27) <= ci(6); -- imm 7
                instr(26) <= ci(7); -- imm 6
                instr(25) <= ci(2); -- imm 5
                instr(24) <= ci(11); -- imm 4
                instr(23 downto 21) <= ci(5 downto 3); -- imm 3-1
                instr(20) <= ci(12); -- imm 11
                instr(19 downto 12) <= (others => ci(12)); -- imm 19-12
                instr(11 downto 7) <= (others => '0');
                instr(6 downto 0) <= RV32I_OP_JAL;
            when "01110" | "01111" => -- C.BEQZ OR C.BNEZ
                instr(31 downto 28) <= (others => ci(12)); -- imm 12-8
                instr(27) <= ci(6); -- imm 7
                instr(26) <= ci(5); -- imm 6
                instr(25) <= ci(2); -- imm 5
                instr(11) <= ci(11); -- imm 4
                instr(10) <= ci(10); -- imm 3
                instr(9) <= ci(4); -- imm 2
                instr(8) <= ci(3); -- imm 1
                instr(7) <= ci(12); -- imm 11
                instr(24 downto 20) <= (others => '0'); -- x0
                instr(19 downto 15) <= "01" & ci(9 downto 7);
                instr(14 downto 12) <= "00" & ci(13);
                instr(6 downto 0) <= RV32I_OP_BRANCH;
            when "10000" => -- C.SLLI
                instr(31 downto 26) <= (others => '0');
                instr(25 downto 20) <= ci(12) & ci(6 downto 2);
                instr(19 downto 15) <= ci(11 downto 7); -- RS1
                instr(14 downto 12) <= "001"; -- FUNCT3
                instr(11 downto 7) <= ci(11 downto 7); -- RD
                instr(6 downto 0) <= RV32I_OP_REG_IMM; -- OPCODE
            when "10010" => -- C.LWSP
                instr(31 downto 28) <= (others => '0'); -- imm 11-8
                instr(27 downto 22) <= ci(3) & ci(2) & ci(12) & ci(6) & ci(5) & ci(4); -- imm 7-2
                instr(21 downto 20) <= (others => '0'); -- imm 1-0
                instr(19 downto 15) <= "00010"; -- SP
                instr(14 downto 12) <= "010";
                instr(11 downto 7) <= ci(11 downto 7); -- RD
                instr(6 downto 0) <= RV32I_OP_LOAD; -- OPCODE
            when "10100" =>
                if ci(12) = '0' then
                    if rs2_zero = '1' then -- C.JR
                        instr(31 downto 20) <= (others => '0'); -- IMM
                        instr(19 downto 15) <= ci(11 downto 7); -- RS1
                        instr(14 downto 12) <= (others => '0'); -- FUNCT3
                        instr(11 downto 7) <= (others => '0'); -- RD = x0
                        instr(6 downto 0) <= RV32I_OP_JALR; -- OPCODE
                    else -- C.MV
                        instr(31 downto 25) <= (others => '0'); -- FUNCT7
                        instr(24 downto 20) <= ci(6 downto 2); -- RS2
                        instr(19 downto 15) <= (others => '0'); -- RS1 = x0
                        instr(14 downto 12) <= (others => '0'); -- FUNCT3
                        instr(11 downto 7) <= ci(11 downto 7); -- RD
                        instr(6 downto 0) <= RV32I_OP_REG_REG; -- OPCODE
                    end if;
                else
                    if rs2_zero = '1' then
                        if rs1_zero = '1' then -- C.EBREAK
                            instr(31 downto 7) <= (31 downto 21 => '0') & '1' & (19 downto 7 => '0'); -- EBREAK
                            instr(6 downto 0) <= RV32I_OP_SYS; -- OPCODE
                        else -- C.JALR
                            instr(31 downto 20) <= (others => '0'); -- IMM
                            instr(19 downto 15) <= ci(11 downto 7); -- RS1 = x0
                            instr(14 downto 12) <= (others => '0'); -- FUNCT3
                            instr(11 downto 7) <= "00001"; -- RD = x1
                            instr(6 downto 0) <= RV32I_OP_JALR; -- OPCODE
                        end if;
                    else -- C.ADD
                        instr(31 downto 25) <= (others => '0'); -- FUNCT7
                        instr(24 downto 20) <= ci(6 downto 2); -- RS2
                        instr(19 downto 15) <= ci(11 downto 7); -- RS1
                        instr(14 downto 12) <= (others => '0'); -- FUNCT3
                        instr(11 downto 7) <= ci(11 downto 7); -- RD
                        instr(6 downto 0) <= RV32I_OP_REG_REG; -- OPCODE
                    end if;
                end if;
            when "10110" => -- C.SWSP
                instr(31 downto 28) <= (others => '0'); -- imm 11-8
                instr(27 downto 25) <= ci(8) & ci(7) & ci(12); -- imm 7-5
                instr(11 downto 9) <= ci(11) & ci(10) & ci(9); -- imm 4-2
                instr(8 downto 7) <= (others => '0'); -- imm 1-0
                instr(24 downto 20) <= ci(6 downto 2); -- RS2
                instr(19 downto 15) <= "00010"; -- RS1 = SP
                instr(14 downto 12) <= "010"; -- FUNCT3
                instr(6 downto 0) <= RV32I_OP_STORE; -- OPCODE
            when others =>
                illegal <= '1';
        end case;
    end process;

    instr_o <= instr(31 downto 16) & ci when illegal = '1' and G_CATCH_ILLEGAL = TRUE else instr;

end architecture rtl;