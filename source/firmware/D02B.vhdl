-- Original: maindec-08-d02b-pb_1-3-68.bin-- This file D02B.vhdl-- CORE memory for the 2100A
--
-- Synchronous read/write block RAM
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity COREMEM is
    port (
        Clock: in  std_logic; 
        ClockEn: in  std_logic; 
        Reset: in  std_logic; 
        WE: in  std_logic; 
        Address: in  std_logic_vector(11 downto 0); 
        Data: in  std_logic_vector(11 downto 0); 
        Q: out  std_logic_vector(11 downto 0)
);

end entity COREMEM;

architecture logic of COREMEM is
    type ram_t is array(natural range 0 to 4095) of std_logic_vector(11 downto 0);
	signal ramdata : ram_t := (
            8#0000# => std_logic_vector(resize(unsigned'(O"5001"), 16)), -- 
       );
	attribute syn_ramstyle : string;
	attribute syn_ramstyle of ramdata : signal is "block_ram";
    signal raddr : integer range 0 to 4095 := 0;
begin
    Q <= ramdata(raddr);

    process (Clock, Reset) is
    begin
        if Reset = '1' then
            raddr <= 0;
        elsif rising_edge(Clock) then
            if ClockEn = '1' then 
                raddr <= to_integer(unsigned(Address));
                if WE = '1' then 
                    ramdata(to_integer(unsigned(Address))) <= Data;
                end if;
            end if;
        end if;
    end process;

end architecture logic;
