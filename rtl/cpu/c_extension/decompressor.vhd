library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.rv32i_pkg.all;

entity decompressor is
    port (
        instr_i : in std_logic_vector(15 downto 0);
        instr_o : out std_logic_vector(31 downto 0)
    );
end entity decompressor;

architecture rtl of decompressor is
    signal rs1_adr, rs2_adr, rd_adr : std_logic_vector(4 downto 0);
    signal crs1_adr, crs2_adr, crd_adr : std_logic_vector(4 downto 0);
    signal ci : std_logic_vector(15 downto 0);
    signal opcode : std_logic_vector(6 downto 0);
    signal instr : std_logic_vector(31 downto 0);
begin
    ci <= instr_i;
    rs1_adr <= ci(11 downto 7);
    rs2_adr <= ci(6 downto 2);
    rd_adr <= ci(11 downto 7);

    process (ci, rs1_adr, rs2_adr)
    begin
        case ci(1 downto 0) is
            when "00" =>
                case ci(15 downto 13) is
                    when "000" => opcode <= RV32I_OP_REG_IMM; -- C.ADDI4SPN
                    when "001" => opcode <= (others => 'X');  -- C.FLD
                    when "010" => opcode <= RV32I_OP_LOAD;    -- C.LW
                    when "011" => opcode <= (others => 'X');  -- C.FLW
                    when "100" => opcode <= (others => 'X');  -- Reserved
                    when "101" => opcode <= (others => 'X');  -- C.FSD
                    when "110" => opcode <= RV32I_OP_STORE;   -- C.SW
                    when "111" => opcode <= (others => 'X');  -- C.FSW
                    when others => opcode <= (others => 'X');
                end case;
            when "01" =>
                case ci(15 downto 13) is
                    when "000" => opcode <= RV32I_OP_REG_IMM; -- C.ADDI
                    when "001" => opcode <= RV32I_OP_JAL;     -- C.JAL
                    when "010" => opcode <= RV32I_OP_REG_IMM; -- C.LI
                    when "011" =>
                        if unsigned(rs1_adr) = 2 then
                            opcode <= RV32I_OP_REG_IMM;       -- C.ADDI16SP
                        else
                            opcode <= RV32I_OP_LUI;           -- C.LUI
                        end if;
                    when "100" =>
                        if ci(11 downto 10) /= "11" then
                            opcode <= RV32I_OP_REG_IMM;       -- C.IMM
                        else
                            opcode <= RV32I_OP_REG_REG;       -- C.REG
                        end if;
                    when "101" => opcode <= RV32I_OP_JAL;     -- C.J
                    when "110" => opcode <= RV32I_OP_BRANCH;  -- C.BEQZ
                    when "111" => opcode <= RV32I_OP_BRANCH;  -- C.BNEZ
                    when others => opcode <= (others => 'X');
                end case;
            when "10" =>
                case ci(15 downto 13) is
                    when "000" => opcode <= RV32I_OP_REG_IMM; -- C.SLLI
                    when "001" => opcode <= (others => 'X');  -- C.FLDSP
                    when "010" => opcode <= RV32I_OP_LOAD;    -- C.LWSP
                    when "011" => opcode <= (others => 'X');  -- C.FLWSP
                    when "100" =>
                        if ci(12) = '0' then
                            if unsigned(rs2_adr) = 0 then
                                opcode <= RV32I_OP_JALR;      -- C.JR
                            else
                                opcode <= RV32I_OP_REG_REG;   -- C.MV
                            end if;
                        else
                            if unsigned(rs2_adr) = 0 then
                                if unsigned(rs1_adr) = 0 then
                                    opcode <= RV32I_OP_SYS;    -- C.EBREAK
                                else
                                    opcode <= RV32I_OP_JALR;   -- C.JR, C.JALR
                                end if;
                            else
                                opcode <= RV32I_OP_REG_REG;    -- C.ADD
                            end if;
                        end if;
                    when "101" => opcode <= (others => 'X');  -- C.FSDSP
                    when "110" => opcode <= RV32I_OP_STORE;   -- C.SWSP
                    when "111" => opcode <= (others => 'X');  -- C.FSWSP
                    when others => opcode <= (others => 'X');
                end case;
            when others => opcode <= (others => 'X');
        end case;
    end process;

    process (ci, opcode, rs1_adr, rs2_adr, rd_adr)
    begin
        instr(6 downto 0) <= opcode;
        case ci(1 downto 0) is
            when "00" =>
                case ci(15 downto 13) is
                    when "000" => -- I-TYPE
                        instr(31 downto 30) <= (others => '0');
                        instr(29 downto 26) <= ci(10 downto 7);
                        instr(25 downto 24) <= ci(12 downto 11);
                        instr(23) <= ci(5);
                        instr(22) <= ci(6);
                        instr(21 downto 20) <= (others => '0');
                        instr(19 downto 15) <= "00010"; -- SP
                        instr(14 downto 12) <= "000";
                        instr(11 downto 7) <= "01" & rs2_adr(2 downto 0); -- crs2_adr is crd_adr
                    when "010" => -- I-TYPE
                        instr(31) <= '0'; -- imm 11
                        instr(30) <= '0'; -- imm 10
                        instr(29) <= '0'; -- imm 09
                        instr(28) <= '0'; -- imm 08
                        instr(27) <= '0'; -- imm 07
                        instr(26) <= ci(5); -- imm 06
                        instr(25) <= ci(12); -- imm 05
                        instr(24) <= ci(11); -- imm 04
                        instr(23) <= ci(10); -- imm 03
                        instr(22) <= ci(6); -- imm 02
                        instr(21) <= '0'; -- imm 01
                        instr(20) <= '0'; -- imm 00
                        instr(19 downto 15) <= "01" & rs1_adr(2 downto 0);
                        instr(14 downto 12) <= "010";
                        instr(11 downto 7) <= "01" & rs2_adr(2 downto 0); -- crs2_adr is crd_adr
                    when "110" => -- S-TYPE
                        instr(31) <= '0'; -- imm 11
                        instr(30) <= '0'; -- imm 10
                        instr(29) <= '0'; -- imm 09
                        instr(28) <= '0'; -- imm 08
                        instr(27) <= '0'; -- imm 07
                        instr(26) <= ci(5); -- imm 06
                        instr(25) <= ci(12); -- imm 05
                        instr(24 downto 20) <= "01" & rs2_adr(2 downto 0);
                        instr(19 downto 15) <= "01" & rs1_adr(2 downto 0);
                        instr(14 downto 12) <= "010";
                        instr(11) <= ci(11); -- imm 4
                        instr(10) <= ci(10); -- imm 3
                        instr(09) <= ci(6); -- imm 2
                        instr(08) <= '0'; -- imm 1
                        instr(07) <= '0'; -- imm 0
                    when others =>
                        instr(31 downto 7) <= (others => 'X');
                end case;
            when "01" =>
                case ci(15 downto 13) is
                    when "000" => -- I-TYPE
                        instr(31 downto 25) <= (others => ci(12));
                        instr(24 downto 20) <= ci(6 downto 2);
                        instr(19 downto 15) <= rs1_adr;
                        instr(14 downto 12) <= "000";
                        instr(11 downto 7) <= rd_adr;
                    when "001" | "101" => -- J-TYPE
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
                        if ci(15) = '0' then -- JAL
                            instr(11 downto 7) <= "00001";
                        else
                            instr(11 downto 7) <= (others => '0');
                        end if;
                    when "010" => -- U-TYPE
                        instr(31 downto 25) <= (others => ci(12));
                        instr(24 downto 20) <= ci(6 downto 2);
                        instr(19 downto 15) <= (others => '0');
                        instr(14 downto 12) <= "000";
                        instr(11 downto 7) <= rd_adr;
                    when "011" =>
                        instr(11 downto 7) <= rd_adr;
                        if unsigned(rs1_adr) = 2 then -- I-TYPE
                            instr(31 downto 29) <= (others => ci(12));
                            instr(28 downto 27) <= ci(4 downto 3);
                            instr(26 downto 24) <= ci(5) & ci(2) & ci(6);
                            instr(23 downto 20) <= (others => '0');
                            instr(19 downto 15) <= rs1_adr;
                            instr(14 downto 12) <= "000";
                        else -- U-TYPE
                            instr(31 downto 17) <= (others => ci(12));
                            instr(16 downto 12) <= ci(6 downto 2);
                        end if;
                    when "100" =>
                        instr(19 downto 15) <= "01" & rs1_adr(2 downto 0);
                        instr(11 downto 07) <= "01" & rd_adr(2 downto 0);
                        case ci(11 downto 10) is
                            when "00" => -- C.SRLI
                                instr(31 downto 20) <= (31 downto 25 => '0') & ci(6 downto 2);
                                instr(14 downto 12) <= "101";
                            when "01" => -- C.SRAI
                                instr(31 downto 20) <= "01" & (29 downto 25 => '0') & ci(6 downto 2);
                                instr(14 downto 12) <= "101";
                            when "10" => -- C.ANDI
                                instr(31 downto 20) <= (31 downto 25 => ci(12)) & ci(6 downto 2);
                                instr(14 downto 12) <= "111";
                            when "11" =>
                                instr(24 downto 20) <= "01" & rs2_adr(2 downto 0);
                                case ci(6 downto 5) is
                                    when "00" => -- C.SUB
                                        instr(31 downto 25) <= "01" & (29 downto 25 => '0');
                                        instr(14 downto 12) <= "000";
                                    when "01" => -- C.XOR
                                        instr(31 downto 25) <= (others => '0');
                                        instr(14 downto 12) <= "100";
                                    when "10" => -- C.OR
                                        instr(31 downto 25) <= (others => '0');
                                        instr(14 downto 12) <= "110";
                                    when "11" => -- C.AND
                                        instr(31 downto 25) <= (others => '0');
                                        instr(14 downto 12) <= "111";
                                    when others => -- NOT SUPPORTED
                                        instr(31 downto 25) <= (others => 'X');
                                        instr(14 downto 12) <= (others => 'X');
                                end case;
                            when others =>
                                instr(31 downto 20) <= (others => 'X');
                                instr(14 downto 12) <= (others => 'X');
                        end case;
                    when "110" | "111" => -- B-TYPE
                        instr(31 downto 28) <= (others => ci(12)); -- imm 12-8
                        instr(27) <= ci(6); -- imm 7
                        instr(26) <= ci(5); -- imm 6
                        instr(25) <= ci(2); -- imm 5
                        instr(11) <= ci(11); -- imm 4
                        instr(10) <= ci(10); -- imm 3
                        instr(9) <= ci(4); -- imm 2
                        instr(8) <= ci(3); -- imm 1
                        instr(7) <= ci(12); -- imm 11
                        instr(24 downto 20) <= (others => '0');
                        instr(19 downto 15) <= "01" & rs1_adr(2 downto 0);
                        instr(14 downto 12) <= "00" & ci(13);
                    when others =>
                        instr(31 downto 7) <= (others => 'X');
                end case;
            when "10" =>
                case ci(15 downto 13) is
                    when "000" => -- I-TYPE
                        instr(31 downto 26) <= (others => '0');
                        instr(25 downto 20) <= ci(12) & ci(6 downto 2);
                        instr(19 downto 15) <= rs1_adr;
                        instr(14 downto 12) <= "001";
                        instr(11 downto 7) <= rd_adr;
                    when "001" =>
                        instr(31 downto 7) <= (others => 'X');
                    when "010" => -- I-TYPE
                        instr(31) <= '0'; -- imm 11
                        instr(30) <= '0'; -- imm 10
                        instr(29) <= '0'; -- imm 9
                        instr(28) <= '0'; -- imm 8
                        instr(27) <= ci(3); -- imm 7
                        instr(26) <= ci(2); -- imm 6
                        instr(25) <= ci(12); -- imm 5
                        instr(24) <= ci(6); -- imm 4
                        instr(23) <= ci(5); -- imm 3
                        instr(22) <= ci(4); -- imm 2
                        instr(21) <= '0'; -- imm 1
                        instr(20) <= '0'; -- imm 0
                        instr(19 downto 15) <= "00010";
                        instr(14 downto 12) <= "010";
                        instr(11 downto 7) <= rd_adr;
                    when "011" =>
                        instr(31 downto 7) <= (others => 'X');
                    when "100" =>
                        if ci(12) = '0' then
                            if unsigned(rs2_adr) = 0 then -- C.JR
                                instr(31 downto 20) <= (others => '0');
                                instr(19 downto 15) <= rs1_adr;
                                instr(14 downto 12) <= (others => '0');
                                instr(11 downto 7) <= (others => '0');
                            else -- C.MV
                                instr(31 downto 25) <= (others => '0');
                                instr(24 downto 20) <= rs2_adr;
                                instr(19 downto 15) <= (others => '0');
                                instr(14 downto 12) <= (others => '0');
                                instr(11 downto 7) <= rd_adr;
                            end if;
                        else
                            if unsigned(rs2_adr) = 0 then -- C.JALR, C.EBREAK
                                if unsigned(rs1_adr) = 0 then
                                    instr(31 downto 7) <= (31 downto 21 => '0') & '1' & (19 downto 7 => '0');
                                else
                                    instr(31 downto 20) <= (others => '0');
                                    instr(19 downto 15) <= rs1_adr;
                                    instr(14 downto 12) <= (others => '0');
                                    instr(11 downto 7) <= "00001";
                                end if;
                            else
                                instr(31 downto 25) <= (others => '0');
                                instr(24 downto 20) <= rs2_adr;
                                instr(19 downto 15) <= rs1_adr;
                                instr(14 downto 12) <= (others => '0');
                                instr(11 downto 7) <= rd_adr;
                            end if;
                        end if;
                    when "101" =>
                        instr(31 downto 7) <= (others => 'X');
                    when "110" =>
                        instr(31) <= '0'; -- imm 11
                        instr(30) <= '0'; -- imm 10
                        instr(29) <= '0'; -- imm 9
                        instr(28) <= '0'; -- imm 8
                        instr(27) <= ci(8); -- imm 7
                        instr(26) <= ci(7); -- imm 6
                        instr(25) <= ci(12); -- imm 5
                        instr(11) <= ci(11); -- imm 4
                        instr(10) <= ci(10); -- imm 3
                        instr(9) <= ci(9); -- imm 2
                        instr(8) <= '0'; -- imm 1
                        instr(7) <= '0'; -- imm 0
                        instr(24 downto 20) <= rs2_adr;
                        instr(19 downto 15) <= "00010";
                        instr(14 downto 12) <= "010";
                    when "111" =>
                        instr(31 downto 7) <= (others => 'X');
                    when others =>
                        instr(31 downto 7) <= (others => 'X');
                end case;
            when others =>
                instr <= (others => 'X');
        end case;
    end process;

    instr_o <= instr;

end architecture rtl;