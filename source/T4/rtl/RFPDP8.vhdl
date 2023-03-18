library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity COREBLOCK is
   port(
      clk_i     : in std_logic;
      we_i      : in std_logic;
      address_i : in std_logic_vector(11 downto 0);
      q_o       : out std_logic_vector(11 downto 0);
      data_i    : in std_logic_vector(11 downto 0)      
   );
end COREBLOCK;

architecture logic of COREBLOCK is
    type core_t is array(natural range 0 to 4095) of std_logic_vector(11 downto 0);
    signal core     : core_t := (
        8#0000# => O"7100", -- CLL
        8#0001# => O"1100", -- TAD 0100 page 0
        8#0002# => O"1101", -- TAD 0101 page 0
        8#0003# => O"2101", -- ISZ 0101 page 0
        8#0004# => O"7200", -- CLA
        8#0005# => O"1102", -- TAD 0102 
        8#0006# => O"7240", -- CLA CMA 
        8#0007# => O"7402", -- HLT
        8#0100# => O"0001",
        8#0101# => O"7777",
        8#0102# => O"7777",
        others => (others => '0')
    );
    signal raddr    : integer range 0 to 4095;
begin
   process(clk_i)
   begin
       if rising_edge(clk_i) then
            if we_i = '1' then
                core(to_integer(unsigned(address_i))) <= data_i;
            end if;
            
       end if;
   end process;
   raddr <= to_integer(unsigned(address_i));
   q_o <= core(raddr) after 50 ns;

end architecture logic;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RFPDP8 is
   port(
      clk_i         : in std_logic;
      reset_i       : in std_logic;
      MA_o          : out std_logic_vector(11 downto 0);
      IBUS_o        : out std_logic_vector(11 downto 0);
      IBUS_i        : in std_logic_vector(11 downto 0);
      READ_o        : out std_logic;
      WRITE_o       : out std_logic
      
   );
end RFPDP8;

architecture logic of RFPDP8 is
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
    constant RFPC       : std_logic_vector(1 downto 0) := "00";
    constant RFAC       : std_logic_vector(1 downto 0) := "01";
    constant RFY        : std_logic_vector(1 downto 0) := "10";
    constant FAND       : std_logic_vector(4 downto 0) := "00000";
    constant FADD       : std_logic_vector(4 downto 0) := "00001";
    constant FIOR       : std_logic_vector(4 downto 0) := "00010";
    constant FCMP       : std_logic_vector(4 downto 0) := "00011";
    constant FA         : std_logic_vector(4 downto 0) := "01111";
    type regfile_t is array(natural range 0 to 3) of std_logic_vector(11 downto 0);
    signal RF           : regfile_t := ( O"0000",  O"0000",  O"0000",  O"0000");
    signal SEQ          : std_logic_vector(11 downto 0); -- sequencer register
    signal IR           : std_logic_vector(11 downto 0); -- instructuion register
    signal SR           : std_logic_vector(11 downto 0); -- shift register
    signal RFO          : std_logic_vector(11 downto 0); -- output of register file
    signal MA           : std_logic_vector(11 downto 0); -- memory address register
    signal TEMP         : std_logic_vector(11 downto 0); -- temp register (used for memory arguments)
    signal ALUO         : std_logic_vector(12 downto 0); -- ALU output
    signal IBUS         : std_logic_vector(11 downto 0); -- internal BUS
    signal PC           : std_logic_vector(11 downto 0); -- dummy
    signal AC           : std_logic_vector(11 downto 0); -- dummy
    signal FALU         : std_logic_vector(4 downto 0); -- ALU function
    signal ADDO         : integer range 0 to 8191; -- Adder output as integer

    signal  CIN         : std_logic;
    signal  HALT        : std_logic := '0';
    signal  HALTSET     : std_logic;
    signal  IRLD        : std_logic;
    signal  IRO         : std_logic;
    signal  LINKCMP     : std_logic;
    signal  LINKCMPT    : std_logic;
    signal  LINKCLR     : std_logic;
    signal  LINKLD      : std_logic;
    signal  LINK        : std_logic;
    signal  MREAD       : std_logic;
    signal  MWRITE      : std_logic;
    signal  NEEDADDR    : std_logic;
    signal  SEQ0        : std_logic;
    signal  SEQ5        : std_logic;
    signal  SEQ8        : std_logic;
    signal  SRLD        : std_logic;
    signal  SRLSL       : std_logic;
    signal  SRLSR       : std_logic;
    signal  SROELO      : std_logic;
    signal  SROEHI      : std_logic;
    signal  TEMPCLR     : std_logic;
    signal  TEMPLD      : std_logic;
    signal  MALD        : std_logic;
    signal  RRF         : std_logic;
    signal  RRFA        : std_logic_vector(1 downto 0);
    signal  WRF         : std_logic;
    signal  WRFA        : std_logic_vector(1 downto 0);
begin

    MA_o    <= MA;
    READ_o  <= MREAD;
    WRITE_o  <= MWRITE;
    IBUS_o  <= IBUS when MWRITE = '1' else (others => 'Z');
    
    IBUS(6 downto 0)    <=  IBUS_i(6 downto 0)  when MREAD = '1' else
                                SR(6 downto 0)  when SROELO = '1' else
                                IR(6 downto 0)  when IRO = '1' else
                            "0000000";
    IBUS(11 downto 7)   <= IBUS_i(11 downto 7)  when MREAD = '1' else
                               SR(11 downto 7)  when SROEHI = '1' else -- results PC
                           "00000";
    
    -- RF
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if WRF = '1' then
                RF(to_integer(unsigned(WRFA))) <= IBUS;
            end if;
        end if;
    end process;
    PC <= RF(0);
    AC <= RF(1);
    RFO <= RF(to_integer(unsigned(RRFA))) when RRF = '1' else O"0000";
    -- TEMP
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if TEMPLD = '1' then
                TEMP <= IBUS;
            elsif TEMPCLR = '1' then
                TEMP <= O"0000";
            end if;
        end if;
    end process;
    
    ADDO <= (to_integer(unsigned(RFO)) +
             to_integer(unsigned(TEMP))) mod 8192 when CIN = '0' else
            (to_integer(unsigned(RFO)) +
             to_integer(unsigned(TEMP)) + 1) mod 8192;

    -- ALU
    ALUO    <= std_logic_vector(to_unsigned(ADDO, 13))                  when FALU = FADD else
               '0' & (RF(to_integer(unsigned(RRFA))) and TEMP)          when FALU = FAND else
               '0' & (RF(to_integer(unsigned(RRFA))) or  TEMP)          when FALU = FIOR else
               '0' & (not RF(to_integer(unsigned(RRFA))))               when FALU = FCMP else
               '0' & RF(to_integer(unsigned(RRFA))); -- default pass through
    -- SR
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if SRLD = '1' then
                SR <= ALUO(11 downto 0);
            elsif SRLSL = '1' then
                SR <= SR(10 downto 0) & LINK;
            elsif SRLSR = '1' then
                SR <= LINK & SR(11 downto 1);
            end if;
        end if;
    end process;
    -- LINK
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if LINKLD = '1' then
                if SRLSL = '1' then
                    LINK <= SR(11);
                elsif SRLSR = '1' then
                    LINK <= SR(0);
                elsif LINKCMP = '1' or (LINKCMPT = '1' and ALUO(12) = '1') then
                    LINK <= not LINK;
                end if;
            elsif LINKCLR = '1' then
                LINK <= '0';
            end if;
        end if;
    end process;
    -- IR
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if IRLD = '1' then
                IR <= IBUS;
            end if;
        end if;
    end process;
    -- MA
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if MALD = '1' then
                MA <= IBUS;
            end if;
        end if;
    end process;

    -- sequencer

    -- HALT 
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if HALTSET = '1' then
                HALT <= '1';
            end if;
        end if;
    end process;

    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            SEQ <= "000000000001";
        elsif falling_edge(clk_i) then
            if HALT = '0' or (HALT = '1' and SEQ(0) = '0') then
                SEQ <= SEQ(10 downto 0) & SEQ(11);
            end if;
        end if;
    end process;
    SEQ0    <= SEQ(0);
    SEQ5    <= SEQ(5);
    SEQ8    <= SEQ(8);
    -- register decode
    -- PC : 00
    -- AC : 01
    -- Y  : 10 ; temp address
    RRFA    <= RFPC when SEQ(0) = '1' else           -- fetch start
               RFPC when SEQ(1) = '1' else           -- fetch latch MA
               RFPC when SEQ(4) = '1' else           -- fetch latch MA, store PC+1
               --RFY  when SEQ(4) = '1' else           -- build address for AND/TAD/ISZ/DCA/JMS/JMP
               RFAC; 
    RRF     <= '1' when (SEQ(0) or SEQ(1) or SEQ(4)) = '1' or 
                        (SEQ(8) = '1' and not std_match(IR, "010---------")) else '0';
    WRFA    <=                                     -- fetch start
                                                   -- fetch latch MA
               RFPC when SEQ(5) = '1' else         -- fetch store PC+1
               --RFPC when SEQ(1) = '1' else         -- store PC to Y too
               --RFPC when SEQ(6) = '1' else         -- store PC to Y too
               RFAC;
    WRF     <= '1' when  SEQ(5) = '1' or             -- store PC + 1
                        (SEQ(6) = '1' and  std_match(IR, "11101-------")) or -- CLA
                        (SEQ(9) = '1' and (std_match(IR, "000---------") or -- AND
                                           std_match(IR, "001---------") or -- TAD
                                           std_match(IR, "1110--1-----"))) else '0'; -- CMA
    -- IR load 
    IRLD    <= SEQ(2);
    -- MREAD memory read
    MREAD   <= '1' when  SEQ(2) = '1' or -- fetch 
                        (SEQ(6) = '1' and NEEDADDR = '1') or -- load value or indirect address
                        (SEQ(7) = '1' and NEEDADDR = '1' and IR(8) = '1') else -- load value or indirect address
               '0';
    -- TEMP register
    TEMPCLR <= '1' when  SEQ(0) = '1' else '0';          -- fetch, PC + 1
               --'1' when  SEQ(4) = '1' and std_match(IR, "1110-1------") else '0';
    TEMPLD  <= '1' when (SEQ(6) = '1' and NEEDADDR = '1' and IR(8) = '0') or 
                        (SEQ(7) = '1' and NEEDADDR = '1' and IR(8) = '1') else '0';

    -- NEEDADDR opcodes that reference memory
    NEEDADDR<= '0' when std_match(IR, "110---------") or -- IO
                        std_match(IR, "111---------") else '1'; -- OPR

    -- ALU function
    FALU    <= FA   when SEQ(0) = '1' else
               FADD when SEQ(4) = '1' else
               FAND when SEQ(8) = '1' and std_match(IR, "000---------") else -- AND
               FADD when SEQ(8) = '1' and std_match(IR, "001---------") else -- TAD
               FADD when SEQ(8) = '1' and std_match(IR, "010---------") else -- ISZ
               FADD when SEQ(8) = '1' and std_match(IR, "100---------") else -- JMS
               FADD when SEQ(8) = '1' and std_match(IR, "100---------") else -- JMS
               FCMP when SEQ(8) = '1' and std_match(IR, "1110--1-----") else -- CMA
               FIOR;
    -- carry in, used for ISZ, PC+1 and IAC
    CIN     <= '1' when SEQ(4) = '1' else                  -- PC+1
               '1' when (SEQ(8) = '1' and std_match(IR, "010---------")) else -- ISZ
               '1' when (SEQ(8) = '1' and std_match(IR, "100---------")) else -- JMS second PC + 1
               '0';
    LINKLD  <= '1' when SEQ(5) = '1' and std_match(IR, "1110----1---") else -- RAL
               '1' when SEQ(5) = '1' and std_match(IR, "1110-----1--") else -- RAR
               '1' when SEQ(6) = '1' and std_match(IR, "1110----1-1-") else -- RTL
               '1' when SEQ(6) = '1' and std_match(IR, "1110-----11-") else -- RTR
               '1' when SEQ(9) = '1' and std_match(IR, "0010--------") else -- TAD complement link if carry
               '0';
    LINKCLR <= '1' when SEQ(5) = '1' and std_match(IR, "1110-1------") else -- CLL
               '0';
    LINKCMP <= '1' when SEQ(5) = '1' and std_match(IR, "1110---1----") else -- CLL
               '0';
    LINKCMPT<= '1' when SEQ(9) = '1' and std_match(IR, "0010--------") else -- TAD complement link if carry
               '0';
    SRLSL   <= '1' when SEQ(5) = '1' and std_match(IR, "1110----1---") else -- RAL
               '1' when SEQ(6) = '1' and std_match(IR, "1110----1-1-") else -- RTL
               '0';
    SRLSR   <= '1' when SEQ(5) = '1' and std_match(IR, "1110-----1--") else -- RAR
               '1' when SEQ(6) = '1' and std_match(IR, "1110-----11-") else -- RTR
               '0';
    SRLD    <= '1' when SEQ(0) = '1' else
               '1' when SEQ(4) = '1' else
               '1' when SEQ(8) = '1' else
               '0';

    SROELO  <= SEQ(1) or  -- PC
               SEQ(5) or  -- PC + 1
               SEQ(9);
    SROEHI  <=  '1' when  SEQ(1) = '1' or
                          SEQ(5) = '1' or  -- PC + 1
                         (SEQ(3) = '1' and NEEDADDR = '1' and IR(7) = '1') else -- current page
                --'1' when SEQ(5) = '1' else 
                '1' when SEQ(9) = '1' else 
                '0';
    -- prepare address
    IRO     <= '1' when SEQ(3) = '1' and NEEDADDR = '1' else 
               '1' when (SEQ(6) = '1' and NEEDADDR = '1' and IR(8) = '1') else 
               '0';
    MALD  <= '1' when SEQ(1) = '1' or
                      (SEQ(3) = '1' and NEEDADDR = '1') or
                      (SEQ(6) = '1' and NEEDADDR = '1' and IR(8) = '1') else
            '0';
    -- write cycle
    MWRITE  <= '1' when SEQ(9) = '1' and (std_match(IR, "010---------") or -- ISZ
                                          std_match(IR, "011---------")) else '0'; -- DCA

    HALTSET <= '1' when SEQ(9) = '1' and std_match(IR, "1111------10") else '0'; -- HLT


    PDP8DIS_i : PDP8DIS
        port map (
            clk_i       => clk_i,
            reset_i     => reset_i,
            -- status
            decode_i    => SEQ(4),
            halted_i    => HALT,
            -- register
            areg_i      => AC,
            ireg_i      => IR,
            mreg_i      => MA,
            preg_i      => PC,
            link_i      => LINK
        );

end architecture logic;


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
    signal io               : integer range 0 to 63;
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
                write(oline, to_oct4(preg_i(11 downto 0)) & " CPU HALTED");
                writeline(OUTPUT, oline);
            end if;
		    if decode_i = '1' then
                cnt := 0;
                write(oline, to_oct4(preg_i(11 downto 0)) & " " & to_oct4(ireg_i) & "  ");
                if IR_OPR1 = '1' then 
                    if BIT_CLA = '1' then write(oline, string'("CLA ")); cnt := cnt + 4; end if;
                    if BIT_CLL = '1' then write(oline, string'("CLL ")); cnt := cnt + 4; end if;
                    if BIT_CMA = '1' then write(oline, string'("CMA ")); cnt := cnt + 4; end if;
                    if BIT_CML = '1' then write(oline, string'("CML ")); cnt := cnt + 4; end if;
                    if BIT_RAR = '1' and BIT_R2 = '0' then write(oline, string'("RAR ")); cnt := cnt + 4; end if;
                    if BIT_RAR = '1' and BIT_R2 = '1' then write(oline, string'("RTR ")); cnt := cnt + 4; end if;
                    if BIT_RAL = '1' and BIT_R2 = '0' then write(oline, string'("RAL ")); cnt := cnt + 4; end if;
                    if BIT_RAL = '1' and BIT_R2 = '1' then write(oline, string'("RTL ")); cnt := cnt + 4; end if;
                    if BIT_IAC = '1' then write(oline, string'("IAC ")); cnt := cnt + 4; end if;
                elsif IR_OPR2 = '1' then 
                    if BIT_CLA = '1' then write(oline, string'("CLA ")); cnt := cnt + 4; end if;
                    if BIT_SMA = '1' then write(oline, string'("SMA ")); cnt := cnt + 4; end if;
                    if BIT_SZA = '1' then write(oline, string'("SZA ")); cnt := cnt + 4; end if;
                    if BIT_SNL = '1' then write(oline, string'("SNL ")); cnt := cnt + 4; end if;
                    if BIT_RSK = '1' then write(oline, string'("RSK ")); cnt := cnt + 4; end if;
                    if BIT_OSR = '1' then write(oline, string'("OSR ")); cnt := cnt + 4; end if;
                    if BIT_HLT = '1' then write(oline, string'("HLT ")); cnt := cnt + 4; end if;
                --elsif 
                else
                    if    ireg_i(8) = '0' and ireg_i(7) = '0' then write(oline, maj_op(maj) & " " & to_oct4(addr) & "   Z"); cnt := cnt + 12;
                    elsif ireg_i(8) = '0' and ireg_i(7) = '1' then write(oline, maj_op(maj) & " " & to_oct4(addr) & "   C"); cnt := cnt + 12;
                    elsif ireg_i(8) = '1' and ireg_i(7) = '0' then write(oline, maj_op(maj) & " " & to_oct4(addr) & " I Z"); cnt := cnt + 12;
                    elsif ireg_i(8) = '1' and ireg_i(7) = '1' then write(oline, maj_op(maj) & " " & to_oct4(addr) & " I C"); cnt := cnt + 12;
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
                write(oline, "  A: " & to_oct4(areg_i) &  "  MA: " & to_oct4(mreg_i) & " LINK: " & to_oct("00" & link_i));
				writeline(OUTPUT, oline);
			end if;
		end if;
    end process; 

end architecture logic;