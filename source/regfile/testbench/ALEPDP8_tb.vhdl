-- Test harness for the PDP8
--
-- Synchronous read/write block RAM
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALEPDP8_tb is

end entity ALEPDP8_tb;

architecture logic of ALEPDP8_tb is
    component COREMEM is
    port (
        Clock: in  std_logic; 
        ClockEn: in  std_logic; 
        Reset: in  std_logic; 
        WE: in  std_logic; 
        Address: in  std_logic_vector(11 downto 0); 
        Data: in  std_logic_vector(11 downto 0); 
        Q: out  std_logic_vector(11 downto 0)
    );
    end component COREMEM;
    component APDP8CPU is
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
    end component APDP8CPU;
    signal data_to_cpu      : std_logic_vector(11 downto 0); -- memory read
    signal cpu_data_to_mem  : std_logic_vector(11 downto 0); -- memory write
    signal cpu_addr         : std_logic_vector(11 downto 0);  --  
    signal cpu_read         : std_logic;  --  
    signal cpu_write        : std_logic;  --  
    signal mem_ready        : std_logic; 
    signal clk              : std_logic; 
    signal reset            : std_logic := '1'; 
    signal io_to_cpu        : std_logic_vector(11 downto 0) := (others => '0');
    signal io_to_io         : std_logic_vector(11 downto 0) := (others => '0');
    signal load_addr        : std_logic := '0';
    signal load_mem         : std_logic := '0';
    signal load_a           : std_logic := '0';
    signal load_b           : std_logic := '0';
    signal load_p           : std_logic := '0';
    signal inc_mem          : std_logic := '0';
    signal dec_mem          : std_logic := '0';
    signal load_m           : std_logic := '0';
    signal disp_a           : std_logic := '0';
    signal disp_b           : std_logic := '0';
    signal disp_m           : std_logic := '0';
    signal disp_p           : std_logic := '0';
    signal single_step      : std_logic := '0';
    signal cpu_halted       : std_logic;
    signal cpu_fetch        : std_logic;
    signal cpu_run          : std_logic := '0';
    signal SRH              : std_logic := '0';
    signal hin              : std_logic;
begin


    APDP8CPU_i : APDP8CPU 
    port map (
        clk_i           => clk,         
        rst_i           => reset,
        data_i          => data_to_cpu,
        data_o          => cpu_data_to_mem,
        addr_o          => cpu_addr,
        read_o          => cpu_read,
        write_o         => cpu_write
    );

    --COREMEM_i : TESTMEM2100A
    COREMEM_i : COREMEM
        port map(
            Clock       => clk,
            ClockEn     => '1',
            Reset       => '0',
            WE          => cpu_write,
            Address     => cpu_addr(11 downto 0),
            Data        => cpu_data_to_mem,
            Q           => data_to_cpu
        );

    mem_ready <= cpu_read or cpu_write;
    
    --process (clk)
    --begin
    --    if rising_edge(clk) then
    --        mem_ready <= cpu_read or cpu_write;
    --    end if;
    --end process;
    process
    begin
        clk <= '0';
        wait for 50 ns;
        clk <= '1';
        wait for 50 ns;
    end process;

    process
    begin
        reset <= '1';
        --cpu_run <= '0';
        --SRH <= '0';
        reset <= '0' after 333 ns;
        --wait for 500 ns;
        --io_to_cpu <= std_logic_vector(resize(unsigned'(O"00100"), 16)); -- initial address
        --load_addr <= '1';
        --wait for 101 ns;
        --load_addr <= '0';
        --wait for 101 ns;
        --io_to_cpu <= X"0010"; -- initial tty
        --wait for 101 ns;
        --io_to_cpu <= X"0040"; -- initial address
        --load_a <= '1';
        --wait for 101 ns;
        --load_a <= '0';
        --wait for 300 ns;
        --cpu_run <= '1';
        --wait for 2 us;
        --cpu_run <= '0';
        --wait for 101 ns;
        --io_to_cpu <= X"0080"; -- initial address
        --load_addr <= '1';
        --wait for 101 ns;
        --load_addr <= '0';
        --io_to_cpu <= X"7FFF"; -- used in test LIA channel 1
        --wait for 300 ns;
        --SRH <= '1';
        wait;
    end process;

end architecture logic;