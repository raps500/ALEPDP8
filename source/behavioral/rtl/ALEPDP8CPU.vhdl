--
-- Ale's PDP-8 
-- Main CPU block 
-- - behavioral  CPU
--
--


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity APDP8CPU is
	port (
        clk_i           : in  std_logic;
        rst_i           : in  std_logic;
        -- Address, data bus
		data_i          : in  std_logic_vector(11 downto 0);
		data_o          : out std_logic_vector(11 downto 0);
        addr_o          : out std_logic_vector(11 downto 0);
        read_o          : out std_logic;
        write_o         : out std_logic
    );
end entity APDP8CPU;


architecture logic of APDP8CPU is

    component PDP8DIS is
        port (
            clk_i           : in std_logic;                     -- sync clock
            reset_i         : in std_logic;                     -- asserted high reset
            -- status
            decode_i        : in std_logic;  -- decode phase, output disassembly
            halted_i        : in std_logic;  -- CPU halted, output disassembly
            -- register
            areg_i          : in std_logic_vector(11 downto 0);
            ireg_i          : in std_logic_vector(11 downto 0);
            mreg_i          : in std_logic_vector(11 downto 0);
            preg_i          : in std_logic_vector(11 downto 0);
            link_i          : in std_logic
        );
    end component PDP8DIS;
    signal IBUS             : std_logic_vector(11 downto 0) := (others => '0');    -- internal bus
    signal AC               : std_logic_vector(11 downto 0) := (others => '0');    -- Accumulator
    signal AD_SUM           : std_logic_vector(11 downto 0) := (others => '0');    -- Accumulator
    signal AND_Q            : std_logic_vector(11 downto 0) := (others => '0');    -- Accumulator
    signal IR               : std_logic_vector(11 downto 0) := (others => '0');    -- instruction register
    signal MA               : std_logic_vector(11 downto 0) := (others => '0');    -- input memory buffer
    signal MBI              : std_logic_vector(11 downto 0) := (others => '0');    -- input memory buffer
    signal MBO              : std_logic_vector(11 downto 0) := (others => '0');    -- output memory buffer
    signal PC               : std_logic_vector(11 downto 0) := (others => '0');    -- programm counter
    signal SEQ              : std_logic_vector(9 downto 0) := (others => '0');    -- sequencer stages
    
    signal AD_SUM_TO_IBUS   : std_logic; -- select AC for left or zero
    signal ALU_LEFT_AC      : std_logic; -- select AC for left or zero
    signal CLR_AC           : std_logic;
    signal HALTED           : std_logic := '0';
    signal INC_PC           : std_logic;
    signal LEFT             : std_logic_vector(11 downto 0);
    signal LINK             : std_logic := '0';
    signal LINK_IN_AC0      : std_logic;
    signal SL_AC            : std_logic;
    signal SR_AC            : std_logic;
    signal CLR_LINK         : std_logic;
    signal CMP_LINK         : std_logic;
    signal SET_LINK         : std_logic;
    signal STO_AC           : std_logic;
    signal STO_LINK         : std_logic;
    signal STO_IR           : std_logic;
    signal STO_MA           : std_logic;
    signal STO_MBI          : std_logic;
    signal STO_MBO          : std_logic;
    signal STO_PC           : std_logic;
    signal AC_TO_IBUS       : std_logic;
    signal AND_Q_TO_IBUS    : std_logic;
    signal PC_TO_IBUS       : std_logic;
    signal ADDR_P0_TO_IBUS  : std_logic;
    signal ADDR_CP_TO_IBUS  : std_logic;

    signal IR_AND           : std_logic; 
    signal IR_TAD           : std_logic; 
    signal IR_ISZ           : std_logic; 
    signal IR_DCA           : std_logic; 
    signal IR_JMS           : std_logic; 
    signal IR_JMP           : std_logic; 
    signal IR_IO            : std_logic; 
    signal IR_OPR1          : std_logic; 
    signal IR_OPR2          : std_logic; 

    signal BIT_CLA          : std_logic; 
    signal BIT_CLL          : std_logic; 
    signal BIT_CMA          : std_logic; 
    signal BIT_CML          : std_logic; 
    signal BIT_RAR          : std_logic; 
    signal BIT_RAL          : std_logic; 
    signal BIT_R2           : std_logic; 
    signal BIT_IAC          : std_logic; 


begin

    data_o  <= MBO;
    addr_o  <= MA;

    -- Memory buffer 
    --
    --

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            MBI <= (others => '0');
        elsif rising_edge(clk_i) then
            if STO_MBI = '1' then
                MBI <= data_i;
            end if;
        end if;
    end process;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            MBO <= (others => '0');
        elsif rising_edge(clk_i) then
            if STO_MBO = '1' then
                MBO <= IBUS;
            end if;
        end if;
    end process;
    -- instruction register
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            IR <= (others => '0');
        elsif rising_edge(clk_i) then
            if STO_IR = '1' then
                IR <= data_i;
            end if;
        end if;
    end process;
    -- accumulator
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            AC <= (others => '0');
        elsif rising_edge(clk_i) then
            if CLR_AC = '1' then
                AC <= "000000000000";
            elsif STO_AC = '1' then
                AC <= IBUS;
            elsif SL_AC = '1' then
                AC <= '0' & AC(11 downto 1);
            elsif SR_AC = '1' then
                AC <= AC(10 downto 0) & '0';
            end if;
        end if;
    end process;
    -- link register
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            LINK <= '0';
        elsif rising_edge(clk_i) then
            if STO_LINK = '1' then
                if LINK_IN_AC0 = '1' then
                    LINK <= AC(0);
                else
                    LINK <= AC(11);
                end if;
            elsif CLR_LINK = '1' then
                LINK <= '0';
            elsif CMP_LINK = '1' then
                LINK <= not LINK;
            elsif SET_LINK = '1' then
                LINK <= '1';
            end if;
        end if;
    end process;
    -- program counter
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            PC <= (others => '0');
        elsif rising_edge(clk_i) then
            if STO_PC = '1' then
                PC <= IBUS;
            elsif INC_PC = '1' then
                PC <= std_logic_vector(unsigned(PC) + 1);
            end if;
        end if;
    end process;

    -- memory address
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            MA <= (others => '0');
        elsif rising_edge(clk_i) then
            if STO_MA = '1' then
                MA <= IBUS;
            end if;
        end if;
    end process;

    -- ALU
    -- add, and, or are the possibilities
    -- ISZ uses add with carry

    LEFT    <=     AC when ALU_LEFT_AC else
               X"000";
    
    AD_SUM  <= std_logic_vector(unsigned(LEFT) + unsigned(MBI));
    AND_Q   <= LEFT and MBI;

    IBUS    <=                                AC when AC_TO_IBUS else
                                           AND_Q when AND_Q_TO_IBUS else
                                          AD_SUM when AD_SUM_TO_IBUS else
                                              PC when PC_TO_IBUS else
                        "00000" & IR(6 downto 0) when ADDR_P0_TO_IBUS else -- address in page zero
                PC(11 downto 7) & IR(6 downto 0) when ADDR_CP_TO_IBUS else -- address in current page
                MBI; -- address or data from memory

    -- Instruction decoder

    IR_AND  <= '1' when std_match(IR(11 downto 0), "000---------") else '0';
    IR_TAD  <= '1' when std_match(IR(11 downto 0), "001---------") else '0';
    IR_ISZ  <= '1' when std_match(IR(11 downto 0), "010---------") else '0';
    IR_DCA  <= '1' when std_match(IR(11 downto 0), "011---------") else '0';
    IR_JMS  <= '1' when std_match(IR(11 downto 0), "100---------") else '0';
    IR_JMP  <= '1' when std_match(IR(11 downto 0), "101---------") else '0';
    IR_IO   <= '1' when std_match(IR(11 downto 0), "110---------") else '0';
    IR_OPR1 <= '1' when std_match(IR(11 downto 0), "1110--------") else '0';
    IR_OPR2 <= '1' when std_match(IR(11 downto 0), "1111--------") else '0';

-- Operate group 1
-- +---+---+---+---+---+---+---+---+---+---+---+---+
-- |           | 0 |CLA|CLL|CMA|CML|RAL|RAR|R2 |IAC| 
-- +---+---+---+---+---+---+---+---+---+---+---+---+
    BIT_CLA <= '1' when std_match(IR(11 downto 0), "----1-------") else '0';
    BIT_CLL <= '1' when std_match(IR(11 downto 0), "-----1------") else '0';
    BIT_CMA <= '1' when std_match(IR(11 downto 0), "------1-----") else '0';
    BIT_CML <= '1' when std_match(IR(11 downto 0), "-------1----") else '0';
    BIT_RAR <= '1' when std_match(IR(11 downto 0), "--------1---") else '0';
    BIT_RAL <= '1' when std_match(IR(11 downto 0), "---------1--") else '0';
    BIT_R2  <= '1' when std_match(IR(11 downto 0), "----------1-") else '0';
    BIT_IAC <= '1' when std_match(IR(11 downto 0), "-----------1") else '0';



    -- sequencing
    -- each opcode (without exception) uses ten phases
    -- each phase is linked to one micro operation like fetch or memory read/write and so on, the longest being JSB

    -- sequencer
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            SEQ <= "0000000001";
        elsif rising_edge(clk_i) then
            if HALTED = '0' then
                SEQ <= SEQ(8 downto 0) & SEQ(9); -- use a circular shift register
            else 
                SEQ <= "0000000001";
            end if;
        end if;
    end process;
    -- Sequencer States
    -- 0 : PC gets copied to MA
    STO_MA      <= SEQ(0);
    PC_TO_IBUS  <= SEQ(0);

    -- 1 : Address output and read, latch of opcode in IR
    read_o      <= SEQ(1);
    STO_IR      <= SEQ(1);
    -- 
    CLR_AC      <= IR_OPR1 and SEQ(2) and BIT_CLA;
    CLR_LINK    <= IR_OPR1 and SEQ(2) and BIT_CLL;


    PDP8DIS_i : PDP8DIS 
        port map(
            clk_i          => clk_i,
            reset_i        => rst_i,
            -- status      
            decode_i       => SEQ(2),
            halted_i       => HALTED,
            -- register   
            areg_i         => AC,
            ireg_i         => IR,
            mreg_i         => MA,
            preg_i         => PC,
            link_i         => LINK
        );

end architecture logic;

-- (c) 2023 Pacito
-- A PDP8 CPU in VHDL
-- based on the documentation on bitsavers and maybe on simh :) 
--
--
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity PDP8DIS is
    port (
        clk_i           : in std_logic;                     -- sync clock
        reset_i         : in std_logic;                     -- asserted high reset
        -- status
        decode_i        : in std_logic;  -- decode phase, output disassembly
        halted_i        : in std_logic;  -- CPU halted, output disassembly
        -- register
        areg_i          : in std_logic_vector(11 downto 0);
        ireg_i          : in std_logic_vector(11 downto 0);
        mreg_i          : in std_logic_vector(11 downto 0);
        preg_i          : in std_logic_vector(11 downto 0);
        link_i          : in std_logic
    );
end entity PDP8DIS;

architecture logic of PDP8DIS is
    signal IR               : std_logic_vector(11 downto 0); 
    signal IR_AND           : std_logic; 
    signal IR_TAD           : std_logic; 
    signal IR_ISZ           : std_logic; 
    signal IR_DCA           : std_logic; 
    signal IR_JMS           : std_logic; 
    signal IR_JMP           : std_logic; 
    signal IR_IO            : std_logic; 
    signal IR_OPR1          : std_logic; 
    signal IR_OPR2          : std_logic; 

    signal BIT_CLA          : std_logic; 
    signal BIT_CLL          : std_logic; 
    signal BIT_CMA          : std_logic; 
    signal BIT_CML          : std_logic; 
    signal BIT_RAR          : std_logic; 
    signal BIT_RAL          : std_logic; 
    signal BIT_R2           : std_logic; 
    signal BIT_IAC          : std_logic; 
    signal BIT_SMA          : std_logic;
    signal BIT_SZA          : std_logic;
    signal BIT_SNL          : std_logic;
    signal BIT_RSK          : std_logic;
    signal BIT_OSR          : std_logic;
    signal BIT_HLT          : std_logic;
    signal BIT_0            : std_logic;
    -- disassember

    type maj_op_t is array(0 to 7) of string(1 to 3);
    constant maj_op     : maj_op_t := ( 
                "AND", "TAD", "ISZ", "DCA",
                "JMS", "JMP", "   ", "   ");
    function to_oct( h : std_logic_vector(2 downto 0) ) return character is
        variable r: character;
        variable i: integer range 0 to 7;
        begin
            i := to_integer(unsigned(h));
            case (i) is
                when  0 => r := character'('0');
                when  1 => r := character'('1');
                when  2 => r := character'('2');
                when  3 => r := character'('3');
                when  4 => r := character'('4');
                when  5 => r := character'('5');
                when  6 => r := character'('6');
                when  7 => r := character'('7');
            end case;
                return r;
    end function;
    function to_oct6(h : std_logic_vector(15 downto 0) ) return string is
        variable r: string(1 to 6);
        begin
            r(1) := to_oct("00" & h(15));
            r(2) := to_oct(h(14 downto 12));
            r(3) := to_oct(h(11 downto  9));
            r(4) := to_oct(h( 8 downto  6));
            r(5) := to_oct(h( 5 downto  3));
            r(6) := to_oct(h( 2 downto  0));
        return r;
    end function;
    function to_oct5(h : std_logic_vector(14 downto 0) ) return string is
        variable r: string(1 to 5);
        begin
            r(1) := to_oct(h(14 downto 12));
            r(2) := to_oct(h(11 downto  9));
            r(3) := to_oct(h( 8 downto  6));
            r(4) := to_oct(h( 5 downto  3));
            r(5) := to_oct(h( 2 downto  0));
        return r;
    end function;
    function to_oct4(h : std_logic_vector(11 downto 0) ) return string is
        variable r: string(1 to 4);
        begin
            r(1) := to_oct(h(11 downto  9));
            r(2) := to_oct(h( 8 downto  6));
            r(3) := to_oct(h( 5 downto  3));
            r(4) := to_oct(h( 2 downto  0));
        return r;
    end function;
    function to_oct3(h : std_logic_vector(8 downto 0) ) return string is
        variable r: string(1 to 3);
        begin
            r(1) := to_oct(h( 8 downto  6));
            r(2) := to_oct(h( 5 downto  3));
            r(3) := to_oct(h( 2 downto  0));
        return r;
    end function;
    function to_oct2(h : std_logic_vector(5 downto 0) ) return string is
        variable r: string(1 to 2);
        begin
            r(1) := to_oct(h( 5 downto  3));
            r(2) := to_oct(h( 2 downto  0));
        return r;
    end function;
    signal addr             : std_logic_vector(11 downto 0); -- integer range 0 to 32767;
    signal maj              : integer range 0 to 7;
    signal io               : integer range 0 to 31;
    signal sr1              : integer range 0 to 7;
    signal sr2              : integer range 0 to 7;
    signal io_select        : std_logic_vector(5 downto 0); -- io select code

begin
    IR <= ireg_i;
    -- Instruction decoder
    IR_AND  <= '1' when std_match(IR(11 downto 0), "000---------") else '0';
    IR_TAD  <= '1' when std_match(IR(11 downto 0), "001---------") else '0';
    IR_ISZ  <= '1' when std_match(IR(11 downto 0), "010---------") else '0';
    IR_DCA  <= '1' when std_match(IR(11 downto 0), "011---------") else '0';
    IR_JMS  <= '1' when std_match(IR(11 downto 0), "100---------") else '0';
    IR_JMP  <= '1' when std_match(IR(11 downto 0), "101---------") else '0';
    IR_IO   <= '1' when std_match(IR(11 downto 0), "110---------") else '0';
    IR_OPR1 <= '1' when std_match(IR(11 downto 0), "1110--------") else '0';
    IR_OPR2 <= '1' when std_match(IR(11 downto 0), "1111--------") else '0';

-- Operate group 1
-- +---+---+---+---+---+---+---+---+---+---+---+---+
-- |           | 0 |CLA|CLL|CMA|CML|RAL|RAR|R2 |IAC| 
-- +---+---+---+---+---+---+---+---+---+---+---+---+
    BIT_CLA <= '1' when std_match(IR(11 downto 0), "----1-------") else '0';
    BIT_CLL <= '1' when std_match(IR(11 downto 0), "-----1------") else '0';
    BIT_CMA <= '1' when std_match(IR(11 downto 0), "------1-----") else '0';
    BIT_CML <= '1' when std_match(IR(11 downto 0), "-------1----") else '0';
    BIT_RAR <= '1' when std_match(IR(11 downto 0), "--------1---") else '0';
    BIT_RAL <= '1' when std_match(IR(11 downto 0), "---------1--") else '0';
    BIT_R2  <= '1' when std_match(IR(11 downto 0), "----------1-") else '0';
    BIT_IAC <= '1' when std_match(IR(11 downto 0), "-----------1") else '0';
    -- group 2
-- Operate group 1
-- +---+---+---+---+---+---+---+---+---+---+---+---+
-- |           | 1 |CLA|SMA|SZA|SNL|RSK|OSR|HLT| 0 | 
-- +---+---+---+---+---+---+---+---+---+---+---+---+
    BIT_SMA <= '1' when std_match(IR(11 downto 0), "-----1------") else '0';
    BIT_SZA <= '1' when std_match(IR(11 downto 0), "------1-----") else '0';
    BIT_SNL <= '1' when std_match(IR(11 downto 0), "-------1----") else '0';
    BIT_RSK <= '1' when std_match(IR(11 downto 0), "--------1---") else '0';
    BIT_OSR <= '1' when std_match(IR(11 downto 0), "---------1--") else '0';
    BIT_HLT <= '1' when std_match(IR(11 downto 0), "----------1-") else '0';
    BIT_0   <= '1' when std_match(IR(11 downto 0), "-----------1") else '0';
    
    -- Disassembler process
    
    maj <= to_integer(unsigned(ireg_i(11 downto  9)));
    io  <= to_integer(unsigned(ireg_i(8 downto 3)));
    --sr1 <= to_integer(unsigned(ireg_i(8 downto 6)));
    --sr2 <= to_integer(unsigned(ireg_i(2 downto 0)));

    addr <= std_logic_vector(unsigned'("00000")) & ireg_i(6 downto 0) when ireg_i(7) = '0' else
            preg_i(11 downto 7) & ireg_i(6 downto 0);

    process (clk_i)
    variable oline : line;
    variable cnt : integer range 0 to 63 := 0;
    begin
        if rising_edge(clk_i) then
            if halted_i = '1' then
                write(oline, to_oct4(mreg_i(11 downto 0)) & " CPU HALTED");
                writeline(OUTPUT, oline);
            end if;
		    if decode_i = '1' then
                cnt := 0;
                write(oline, to_oct4(mreg_i(11 downto 0)) & " " & to_oct4(ireg_i) & "  ");
                if IR_OPR1 = '1' then 
                    if BIT_CLA = '1' then write(oline, string'("CLA ")); cnt := cnt + 4; end if;
                    if BIT_CLL = '1' then write(oline, string'("CLL ")); cnt := cnt + 4; end if;
                    if BIT_CMA = '1' then write(oline, string'("CMA ")); cnt := cnt + 4; end if;
                    if BIT_CML = '1' then write(oline, string'("CML ")); cnt := cnt + 4; end if;
                    if BIT_RAR = '1' and BIT_R2 = '0' then write(oline, string'("RAR ")); cnt := cnt + 4; end if;
                    if BIT_RAR = '1' and BIT_R2 = '1' then write(oline, string'("RAR RAR ")); cnt := cnt + 8; end if;
                    if BIT_RAL = '1' and BIT_R2 = '0' then write(oline, string'("RAL RAL ")); cnt := cnt + 8; end if;
                    if BIT_RAL = '1' and BIT_R2 = '1' then write(oline, string'("RAL ")); cnt := cnt + 4; end if;
                    if BIT_IAC = '1' then write(oline, string'("IAC ")); cnt := cnt + 4; end if;
                elsif IR_OPR2 = '1' then 
                    if BIT_CLA = '1' then write(oline, string'("CLA ")); cnt := cnt + 4; end if;
                    if BIT_SMA = '1' then write(oline, string'("SMA ")); cnt := cnt + 4; end if;
                    if BIT_SZA = '1' then write(oline, string'("SZA ")); cnt := cnt + 4; end if;
                    if BIT_SNL = '1' then write(oline, string'("SNL ")); cnt := cnt + 4; end if;
                    if BIT_RSK = '1' then write(oline, string'("RSK ")); cnt := cnt + 4; end if;
                    if BIT_OSR = '1' then write(oline, string'("OSR ")); cnt := cnt + 8; end if;
                    if BIT_HLT = '1' then write(oline, string'("HLT ")); cnt := cnt + 8; end if;
                --elsif 
                else
                    if    ireg_i(8) = '0' and ireg_i(7) = '0' then write(oline, maj_op(maj) & " " & to_oct4(addr) & "   Z"); cnt := cnt + 13;
                    elsif ireg_i(8) = '0' and ireg_i(7) = '1' then write(oline, maj_op(maj) & " " & to_oct4(addr) & "   C"); cnt := cnt + 13;
                    elsif ireg_i(8) = '1' and ireg_i(7) = '0' then write(oline, maj_op(maj) & " " & to_oct4(addr) & " I Z"); cnt := cnt + 13;
                    elsif ireg_i(8) = '1' and ireg_i(7) = '1' then write(oline, maj_op(maj) & " " & to_oct4(addr) & " I C"); cnt := cnt + 13;
                    end if;
                end if;
                case (cnt) is
                    when  3 => write(oline, string'("                             "));
                    when  4 => write(oline, string'("                            "));
                    when  5 => write(oline, string'("                           "));
                    when  8 => write(oline, string'("                        "));
                    when 12 => write(oline, string'("                    "));
                    when 13 => write(oline, string'("                   "));
                    when 16 => write(oline, string'("                "));
                    when 20 => write(oline, string'("            "));
                    when 24 => write(oline, string'("        "));
                    when others => write(oline, string'("    "));
                end case;
                write(oline, "  A: " & to_oct4(areg_i) & " LINK: " & to_oct("00" & link_i));
				writeline(OUTPUT, oline);
			end if;
		end if;
    end process; 

end architecture logic;