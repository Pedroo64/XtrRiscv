library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package vhdl_utils is
    function or_reduct(x : std_logic_vector) return std_logic;
    function and_reduct(x : std_logic_vector) return std_logic;
    
    procedure vhdl_assert(cond : in boolean; message : in string; sev_level : in severity_level := FAILURE);
    procedure vhdl_assert(cond : in std_logic; message : in string; sev_level : in severity_level := FAILURE);
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
    
end package body vhdl_utils;
