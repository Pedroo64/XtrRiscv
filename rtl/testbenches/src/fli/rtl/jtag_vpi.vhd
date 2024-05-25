library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity jtag_vpi is
    port (
        clk_i : in std_logic;
        tck_o : out std_logic;
        tdi_o : out std_logic;
        tms_o : out std_logic;
        tdo_i : in std_logic
    );
end entity jtag_vpi;

architecture c_model of jtag_vpi is
    attribute foreign : string;
--    attribute foreign of c_model : architecture is "jtag_init ../../testbenches/src/fli/lib/libfli.so; verbose";
    attribute foreign of c_model : architecture is "jtag_init ../../testbenches/src/fli/build/bin/Debug/fli.dll; verbose";
begin

end architecture c_model;