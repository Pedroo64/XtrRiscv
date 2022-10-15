library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package dtm_pkg is
--  |-------|-----------------------------------------------------------------------|
--  | R     | Read-only.                                                            |
--  |-------|-----------------------------------------------------------------------|
--  | R/W   | Read/Write.                                                           |
--  |-------|-----------------------------------------------------------------------|
--  | R/W1C | Read/Write Ones to Clear. Writing 0 to every bit has no effect.       |
--  |       | Writing 1 to every bit clears the field. The result of other writes   |
--  |       | is undefined.                                                         |
--  |-------|-----------------------------------------------------------------------|
--  | WARZ  | Write any, read zero. A debugger may write any value. When read this  | 
--  |       | field returns 0.                                                      |
--  |-------|-----------------------------------------------------------------------|
--  | W1    | Write-only. Only writing 1 has an effect. When read the returned      |
--  |       | value should be 0.                                                    |
--  |-------|-----------------------------------------------------------------------|
--  | WARL  | Write any, read legal. A debugger may write any value. If a value is  |
--  |       | unsupported, the implementation converts the value to one that is     |
--  |       | supported                                                             |
--  |-------|-----------------------------------------------------------------------|

type dtmcs_t is record
    dmihardreset : std_logic; -- 17, W1
    dmireset : std_logic; -- 16, W1
    idle : std_logic_vector(2 downto 0); -- 14 downto 12, R
    dmistat : std_logic_vector(1 downto 0); -- 11 downto 10, R
    abits : std_logic_vector(5 downto 0); -- 9 downto 4, R
    version : std_logic_vector(3 downto 0); -- 3 downto 0, R
end record dtmcs_t;

type dmi_t is record
    address : std_logic_vector(7 downto 0); -- 41 downto 34, R/W
    data : std_logic_vector(31 downto 0); -- 33 downto 2, R/W
    op : std_logic_vector(1 downto 0); -- 1 downto 0, R/W
end record dmi_t;

function get_dmi (dmi : dmi_t) return std_logic_vector;
function get_dtmcs (dtmcs : dtmcs_t) return std_logic_vector;

    
end package dtm_pkg;

package body dtm_pkg is
function get_dmi (dmi : dmi_t) return std_logic_vector is
    variable data : std_logic_vector(41 downto 0);
begin
    data(41 downto 34) := dmi.address;
    data(33 downto 2) := dmi.data;
    data(1 downto 0) := dmi.op;
    return data;
end function;
function get_dtmcs (dtmcs : dtmcs_t) return std_logic_vector is
    variable data : std_logic_vector(31 downto 0);
begin
    data(31 downto 18) := (others => '0');
    data(17) := dtmcs.dmihardreset;
    data(16) := dtmcs.dmireset;
    data(15) := '0';
    data(14 downto 12) := dtmcs.idle;
    data(11 downto 10) := dtmcs.dmistat;
    data(9 downto 4) := dtmcs.abits;
    data(3 downto 0) := dtmcs.version;
    return data;
end function;
end package body;