library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use IEEE.std_logic_textio.all;
use std.textio.all;

package vhdl_utils is
    function or_reduct(x : std_logic_vector) return std_logic;
    function and_reduct(x : std_logic_vector) return std_logic;

    procedure vhdl_assert(cond : in boolean; message : in string; sev_level : in severity_level := FAILURE);
    procedure vhdl_assert(cond : in std_logic; message : in string; sev_level : in severity_level := FAILURE);

    function to_hex_str(slv : std_logic_vector) return string;
end package;

package body vhdl_utils is

    function or_reduct(x : std_logic_vector) return std_logic is
        variable ret : std_logic;
    begin
        ret := '0';
        for i in x'range loop
            ret := ret or x(i);
        end loop;
        return ret;
    end function;
    function and_reduct(x : std_logic_vector) return std_logic is
        variable ret : std_logic;
    begin
        ret := '0';
        for i in x'range loop
            ret := ret and x(i);
        end loop;
        return ret;
    end function;

    procedure vhdl_assert(cond : in boolean; message : in string; sev_level : in severity_level := FAILURE) is
    begin
        assert not cond report message & " at " & time'image(now) severity sev_level;
    end procedure;
    procedure vhdl_assert(cond : in std_logic; message : in string; sev_level : in severity_level := FAILURE) is
    begin
        vhdl_assert(cond = '1', message, sev_level);
    end procedure;

    function to_hex_str(slv : std_logic_vector) return string is
        variable s : string(1 to 64);
        variable c : character;
        variable i : integer;
        variable r, l : integer;
    begin
        i := slv'right;
        while i < (slv'left + 1) loop
            r := i;
            l := r + 3;
            if l > slv'left then
                l := slv'left;
            end if;
            case to_integer(unsigned(slv(l downto r))) is
                when 16#0# => c := '0';
                when 16#1# => c := '1';
                when 16#2# => c := '2';
                when 16#3# => c := '3';
                when 16#4# => c := '4';
                when 16#5# => c := '5';
                when 16#6# => c := '6';
                when 16#7# => c := '7';
                when 16#8# => c := '8';
                when 16#9# => c := '9';
                when 16#A# => c := 'A';
                when 16#B# => c := 'B';
                when 16#C# => c := 'C';
                when 16#D# => c := 'D';
                when 16#E# => c := 'E';
                when 16#F# => c := 'F';
                when others => c := 'X';
            end case;
            s := c & s(1 to 63);
            i := i + 4;
        end loop;
        return s;
    end function;

end package body vhdl_utils;