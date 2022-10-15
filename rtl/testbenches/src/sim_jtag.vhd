library IEEE;
use IEEE.std_logic_1164.all;

entity sim_jtag is
    port (
        arst_i : in std_logic;
        clk_i : in std_logic;
        tck_o : out std_logic;
        tdi_o : out std_logic;
        tms_o : out std_logic;
        tdo_i : in std_logic
    );
end entity sim_jtag;

architecture c_model of sim_jtag is
    attribute foreign : string;
    attribute foreign of c_model : architecture is "jtag_init ../../testbenches/fli/bin/fli.so; verbose";
begin
end architecture c_model;