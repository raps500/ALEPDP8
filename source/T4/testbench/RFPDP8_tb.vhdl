
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RFPDP8_tb is

end RFPDP8_tb;

architecture logic of RFPDP8_tb is
    component RFPDP8 is
        port(
           clk_i         : in std_logic;
           reset_i       : in std_logic;
           MA_o          : out std_logic_vector(11 downto 0);
           IBUS_o        : out std_logic_vector(11 downto 0);
           IBUS_i        : in std_logic_vector(11 downto 0);
           READ_o        : out std_logic;
           WRITE_o       : out std_logic
           
        );
     end component RFPDP8;
     component COREBLOCK is
        port(
           clk_i     : in std_logic;
           we_i      : in std_logic;
           address_i : in std_logic_vector(11 downto 0);
           q_o       : out std_logic_vector(11 downto 0);
           data_i    : in std_logic_vector(11 downto 0)      
        );
        end component COREBLOCK;
    signal    clk           : std_logic := '0'; -- clock
    signal    reset         : std_logic := '0'; -- active high reset
    signal    CORETOCPU     : std_logic_vector(11 downto 0); -- reg_data_to_periph
    signal    CPUTOCORE     : std_logic_vector(11 downto 0); -- reg_data_to_periph
    signal    MA            : std_logic_vector(11 downto 0); -- Register address
    signal    MREAD        : std_logic;                    -- write strobe
    signal    MWRITE        : std_logic;                    -- write strobe
    
begin

    COREBLOCK_i : COREBLOCK
        port map(
           clk_i     => clk,
           we_i      => MWRITE, 
           address_i => MA,
           q_o       => CORETOCPU,
           data_i    => CPUTOCORE
        );
    RFPDP8_i : RFPDP8
        port map (
            clk_i         => clk,
            reset_i       => reset,
            MA_o          => MA,
            IBUS_o        => CPUTOCORE,
            IBUS_i        => CORETOCPU,
            READ_o        => MREAD,
            WRITE_o       => MWRITE
            
        );
    process 
        begin
            clk        <= '0';
            wait for 500 ns;
            clk        <= '1';
            wait for 500 ns;
        end process;
    process 
        begin
            reset        <= '1';
            wait for 2233 ns;
            reset        <= '0';
            wait;
        end process;
        
        
end architecture logic;




