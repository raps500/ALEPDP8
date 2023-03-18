-- Ale's PDP-8 
-- Microcode
-- - 
--
--


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MC is
	port (
        data_o          : out std_logic_vector(15 downto 0);
        addr_i          : in std_logic_vector(10 downto 0)        
    );
end entity MC;


architecture logic of MC is
    type rom_t is array(natural range 0 to 2047) of std_logic_vector(15 downto 0);
    constant AC     : std_logic_vector(1 downto 0) := "00";
    constant PC     : std_logic_vector(1 downto 0) := "01";
    constant  Q     : std_logic_vector(1 downto 0) := "10";
    constant  Y     : std_logic_vector(1 downto 0) := "11";
    constant  x     : std_logic := '0';
    constant  RFR   : std_logic := '1';
    constant  RFW   : std_logic := '1';
    constant  TEMPOE: std_logic := '1';
    constant  TEMPLD: std_logic := '1';
    constant  FAND  : std_logic_vector(1 downto 0) := "00";
    constant  FADD  : std_logic_vector(1 downto 0) := "01";
    constant  FLSL  : std_logic_vector(1 downto 0) := "10";
    constant  FIOR  : std_logic_vector(1 downto 0) := "11";
    constant  LLD   : std_logic := '1';
    constant  SR    : std_logic := '1';
    constant  NBHZ  : std_logic_vector(1 downto 0) := "00";
    constant  IROE  : std_logic_vector(1 downto 0) := "01";
    constant  SROE  : std_logic_vector(1 downto 0) := "10";
    constant  MREAD : std_logic_vector(1 downto 0) := "11";
    constant  MWRITE: std_logic := '1';
    constant  MALD  : std_logic := '1';

	signal microcode : rom_t := (
        --          2     1    2     1        1        1      2    1      2     1        1      1   
        --         ..   ...   ..   ...   TEMPOE   TEMPLD   FUNC   SR   IBUS   LDD   MWRITE   MALD
        16#000# => PC & RFR & AC & x   & x      &      x & FAND &  x & SROE &   x &      x & MALD,
        16#001# => PC & RFR & AC & x   & x      &      x & FAND &  x & SROE &   x &      x & MALD,
        others => (others => '0')
    );
begin
    data_o <= microcode(to_integer(unsigned(addr_i)));
end architecture logic;
