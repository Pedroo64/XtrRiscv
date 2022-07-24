library IEEE;
use IEEE.std_logic_1164.all;

package debug_module_pkg is
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

    constant C_DATA0 : integer := 16#04#;
    constant C_DMCONTROL : integer := 16#10#;
    constant C_DMSTATUS : integer := 16#11#;
    constant C_HARTINFO : integer := 16#12#;
    constant C_ABSTRACTCS : integer := 16#16#;
    constant C_COMMAND : integer := 16#17#;
    constant C_NEXTDM : integer := 16#1D#;
    constant C_PROGBUF0 : integer := 16#20#;

    type dmcontrol_t is record
        haltreq : std_logic; -- 31, WARZ
        resumereq : std_logic; -- 30, W1
        hartreset : std_logic; -- 29, WARL
        ackhavereset : std_logic; -- 28, W1
        ackunavail : std_logic; -- 27, W1
        hasel : std_logic; -- 26, WARL
        hartsello : std_logic_vector(9 downto 0); -- 25 downto 16, WARL
        hartselhi : std_logic_vector(9 downto 0); -- 15 downto 6, WARL
        setkeepalive : std_logic; -- 5, W1
        clrkeepalive : std_logic; -- 4, W1
        setresethaltreq : std_logic; -- 3, W1
        clrresethaltreq : std_logic; -- 2, W1
        ndmreset : std_logic; -- 1, R/W
        dmactive : std_logic; -- 0, R/W
    end record dmcontrol_t;

    type dmstatus_t is record
        ndmresetpending : std_logic; -- 24, R
        stickyunavail : std_logic; -- 23, R
        impebreak : std_logic; -- 22, R
        allhavereset : std_logic; -- 19, R
        anyhavereset : std_logic; -- 18, R
        allresumeack : std_logic; -- 17, R
        anyresumeack : std_logic; -- 16, R
        allnonexistent : std_logic; -- 15, R
        anynonexistent : std_logic; -- 14, R
        allunavail : std_logic; -- 13, R
        anyunavail  : std_logic; -- 12, R
        allrunning : std_logic; -- 11, R
        anyrunning : std_logic; -- 10, R
        allhalted : std_logic; -- 9, R
        anyhalted : std_logic; -- 8, R
        authenticated : std_logic; -- 7, R
        authbusy : std_logic; -- 6, R
        hasresethaltreq : std_logic; -- 5, R
        confstrptrvalid : std_logic; -- 4, R
        version : std_logic_vector(3 downto 0); -- 3 downto 0, R
    end record dmstatus_t;

    type abstractcs_t is record
        progbufsize : std_logic_vector(4 downto 0); -- 28 downto 24, R
        busy : std_logic; -- 12, R
        relaxedpriv : std_logic; -- 11, WARL
        cmderr : std_logic_vector(2 downto 0); -- 10 downto 8, R/W1C
        datacount : std_logic_vector(3 downto 0); -- 3 downto 0, R
    end record abstractcs_t;

    type command_t is record
        cmdtype : std_logic_vector(7 downto 0); -- 31 downto 24, WARZ
        control : std_logic_vector(23 downto 0); -- 23 downto 0, WARZ
    end record command_t;

    type hartinfo_t is record
        nscratch : std_logic_vector(3 downto 0); -- 23 downto 20, R
        dataaccess : std_logic; -- 16, R
        datasize : std_logic_vector(4 downto 0); -- 15 downto 12, R
        dataaddr : std_logic_vector(11 downto 0); -- 11 downto 0, R
    end record hartinfo_t;


    type debug_module_registers_t is record
        data0 : std_logic_vector(31 downto 0); -- R/W
        dmcontrol : dmcontrol_t;
        dmstatus : dmstatus_t;
        hartinfo : hartinfo_t;
        abstractcs : abstractcs_t;
        command : command_t;
        nextdm : std_logic_vector(31 downto 0); -- R
        progbuf0 : std_logic_vector(31 downto 0); -- R/W
    end record debug_module_registers_t;

    type access_register_command_t is record -- Image of command_t.control
        aarsize : std_logic_vector(2 downto 0); -- 22 downto 20
        aarpostincrement : std_logic; -- 19
        postexec : std_logic; -- 18
        transfer : std_logic; -- 17
        write : std_logic; -- 16
        regno : std_logic_vector(15 downto 0); -- 15 downto 0
    end record access_register_command_t;

    constant ABSTRACTCS_CMDERR_NONE : std_logic_vector(2 downto 0) := o"0";
    constant ABSTRACTCS_CMDERR_BUSY : std_logic_vector(2 downto 0) := o"1";
    constant ABSTRACTCS_CMDERR_NOT_SUPPORTED : std_logic_vector(2 downto 0) := o"2";
    constant ABSTRACTCS_CMDERR_EXCEPTION : std_logic_vector(2 downto 0) := o"3";
    constant ABSTRACTCS_CMDERR_HALT_RESUME : std_logic_vector(2 downto 0) := o"4";
    constant ABSTRACTCS_CMDERR_BUS : std_logic_vector(2 downto 0) := o"5";
    constant ABSTRACTCS_CMDERR_OTHER : std_logic_vector(2 downto 0) := o"7";
    
end package debug_module_pkg;