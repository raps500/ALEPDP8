#!/usr/bin/python3

from sys import argv
OCTAL = False

#
# Let's see which conversion works better, I assume the 
#

def convert_blob(blob):
    newblob = []
    for i in range(len(blob) >> 1):
        
        newblob.append((blob[i<<1] << 6) + blob[(i<<1)+1])
    return newblob

def process_abin(ifilename, ofilename, start_addr, skip):
    try:
        fi = open(ifilename, 'rb')
    except:
        print('Cannot open ', ifilename)
        return
    try:
        fo = open(ofilename, 'wt')
    except:
        print('Cannot owrite to ', ofilename)
        return

    fo.write('-- Original: %s' % ifilename)
    fo.write('-- This file %s' % ofilename)
    fo.write('''-- CORE memory for the 2100A
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
''')

    blob = fi.read()

    addr = start_addr
    for j in range(skip, len(blob)>>1):
        h = blob[j<<1]
        l = blob[(j<<1) + 1] 
        opcode = (h << 6) + l
        if h >= 64:
            addr = ((h << 8) + l)  & 0xfff
        else:
            if OCTAL:
                fo.write('            8#%04o# => std_logic_vector(resize(unsigned\'(O\"%04o\"), 16)), -- ' %(addr, opcode))
            else:
                fo.write('            %6d => X\"%04x", -- ' %(addr, opcode))
            fo.write('\r')
            addr += 1
    fo.write('            others  => X\"0000\"')
    fo.write('''
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

''')
    
    fi.close()
    fo.close()

if __name__ == '__main__':
    abin = None
    ofile = None
    start_addr = 0
    skip = 55
    for a in argv:
        try:
            addr = int(a[2:], 8)
        except:
            addr = None
        if '.bin' in a:
            abin = a
        elif '-O' == a:
            OCTAL = True
        elif '-A' in a and addr != None:
            start_addr = addr
        elif '-S' in a and addr != None:
            skip = addr
        else:
            ofile = a

    process_abin(abin, ofile, start_addr, skip)
