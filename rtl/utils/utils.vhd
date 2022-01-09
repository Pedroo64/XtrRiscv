library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

package utils is

    function bit_width (value : integer) return integer;
    function freq2real(freq_out : real; freq_in : real; N : integer) return real;
    function freq2unsigned(freq_out : real; freq_in : real; N : integer) return unsigned;
    function freq2slv(freq_out : real; freq_in : real; N : integer) return std_logic_vector;
end package utils;

package body utils is
    function bit_width (value : integer) return integer is
        variable ret              : integer;
    begin
        if value = 0 then
            ret := - 1;
        elsif value = 1 then
            ret := 1;
        else
            ret := integer(ceil(log2(real(value))));
        end if;
        return ret;
    end function;
    function freq2real(freq_out : real; freq_in : real; N : integer) return real is
    begin
        return (freq_out * (2.0 ** N)) / freq_in;
    end function;
    function freq2unsigned(freq_out : real; freq_in : real; N : integer) return unsigned is
    begin
        return to_unsigned(integer(freq2real(freq_out, freq_in, N)), N);
    end function;
    function freq2slv(freq_out : real; freq_in : real; N : integer) return std_logic_vector is
    begin
        return std_logic_vector(freq2unsigned(freq_out, freq_in, N));
    end function;
end package body;