-- Test harness for the 2100A
--
-- Synchronous read/write block RAM
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity HP2100A_tb is

end entity HP2100A_tb;

architecture logic of HP2100A_tb is
    component COREMEM is
    port (
        Clock: in  std_logic; 
        ClockEn: in  std_logic; 
        Reset: in  std_logic; 
        WE: in  std_logic; 
        Address: in  std_logic_vector(12 downto 0); 
        Data: in  std_logic_vector(15 downto 0); 
        Q: out  std_logic_vector(15 downto 0)
    );
    end component COREMEM;
    component CPU2100A is
    port (
        clk_i           : in std_logic;                     -- sync clock
        reset_i         : in std_logic;                     -- asserted high reset
        -- status
        CW_i            : in std_logic; -- 
        RW_i            : in std_logic; -- 
        SIOB_i          : in std_logic; -- 
        READ_i          : in std_logic; -- 
        HIN_i           : in std_logic; -- 
        HIN_o           : out std_logic; -- 
        INCM_i          : in std_logic; -- panel increment memory address
        DECM_i          : in std_logic; -- panel decrement memory address
        SRH_i           : in std_logic; -- panel 
        SSIN_i          : in std_logic; -- panel 
        SSCY_i          : in std_logic; -- panel 
        EXTEND_i        : in std_logic; -- 
        OVFF_o          : out std_logic; --
        LOAD_i          : in std_logic; --
        PRSI_i          : in std_logic; --
        PRSE_i          : in std_logic; --
        EPRSE_o         : out std_logic; --
        SCF0_i          : in std_logic; --
        SCE_i           : in std_logic; --
        SCO_i           : in std_logic; --
        PNLA_i          : in std_logic; -- panel load A
        RRSB_i          : in std_logic; -- panel load B
        PNLB_i          : in std_logic; -- panel load B
        IOI_i           : in std_logic; -- panel load P
        STORE_i         : in std_logic; -- panel load P
        PNLP_i          : in std_logic; -- panel load P
        FETCH_i         : in std_logic; -- panel load P
        SELM_i          : in std_logic; -- panel load P
        PNLT_i          : in std_logic; -- panel load P
        -- memory subsystem
        mem_data_i      : in std_logic_vector(15 downto 0); -- memory read
        mem_data_o      : out std_logic_vector(15 downto 0); -- memory write
        mem_addr_o      : out std_logic_vector(14 downto 0);  --  
        mem_read_o      : out std_logic;  --  
        mem_write_o     : out std_logic;  --  
        mem_ready_i     : in std_logic;   -- set to 1 when the memory  is ready
        -- IO subsytems
        io_select_o     : out std_logic_vector(5 downto 0) ;  
        io_data_o       : out std_logic_vector(15 downto 0); -- io write
        io_data_i       : in std_logic_vector(15 downto 0); -- io read
        io_PRH_o        : out std_logic;    -- priority high
        io_SIR_o        : out std_logic;    -- set interrupt request (periodic at T5)
        io_IEN_o        : out std_logic;    -- interrupt enable
        io_ENF_o        : out std_logic;    -- enable flag (periodic at T2)
        io_POPIO_o      : out std_logic;    -- power-on preset to I/O
        io_STF_o        : out std_logic;    -- set the flag flip-flop
        io_IAK_o        : out std_logic;    -- interrupt acknowledge
        io_CLF_o        : out std_logic;    -- clear the flag flip-flop
        io_STC_o        : out std_logic;    -- set the control flip-flop
        io_CLC_o        : out std_logic;    -- clear the control flip-flop
        io_CRS_o        : out std_logic;    -- control reset
        io_SFC_o        : out std_logic;    -- skip if the flag is clear
        io_SFS_o        : out std_logic;    -- skip if the flag is set
        -- The CPU receives these backplane signals from the interface:
        io_PRL_i        : in std_logic;     -- priority low
        io_SRQ_i        : in std_logic;     -- service request
        io_FLG_i        : in std_logic;     -- flag
        io_IRQ_i        : in std_logic;     -- interrupt request
        io_SKF_i        : in std_logic      -- skip on flag
    );
    end component CPU2100A;
    signal data_to_cpu      : std_logic_vector(15 downto 0); -- memory read
    signal cpu_data_to_mem  : std_logic_vector(15 downto 0); -- memory write
    signal cpu_addr         : std_logic_vector(14 downto 0);  --  
    signal cpu_read         : std_logic;  --  
    signal cpu_write        : std_logic;  --  
    signal mem_ready        : std_logic; 
    signal clk              : std_logic; 
    signal reset            : std_logic := '1'; 
    signal io_to_cpu        : std_logic_vector(15 downto 0) := (others => '0');
    signal io_to_io         : std_logic_vector(15 downto 0) := (others => '0');
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


    CPU2100A_i : CPU2100A 
    port map (
        clk_i           => clk,         
        reset_i         => reset,
        CW_i            => '0',
        RW_i            => '0',
        SIOB_i          => '0',
        READ_i          => '0',
        HIN_i           => '0',
        HIN_o           => hin,
        INCM_i          => '0',
        DECM_i          => '0',
        SRH_i           => '0',
        SSIN_i          => '0',
        SSCY_i          => '0',
        EXTEND_i        => '0',
        OVFF_o          => open,
        LOAD_i          => '0',
        PRSI_i          => '0',
        PRSE_i          => '0',
        EPRSE_o         => open,
        SCF0_i          => '0',
        SCE_i           => '0',
        SCO_i           => '0',
        PNLA_i          => load_a,
        RRSB_i          => '0',
        PNLB_i          => load_b,
        IOI_i           => '0',
        STORE_i         => '0',
        PNLP_i          => '0',
        FETCH_i         => '0',
        SELM_i          => '0',
        PNLT_i          => '0',
        -- memory subsystem
        mem_data_i      => data_to_cpu,
        mem_data_o      => cpu_data_to_mem,
        mem_addr_o      => cpu_addr,
        mem_read_o      => cpu_read,
        mem_write_o     => cpu_write,
        mem_ready_i     => mem_ready,
        -- 
        -- IO subsytems
        io_select_o     => open,
        io_data_o       => io_to_io,
        io_data_i       => io_to_cpu,
        io_PRH_o        => open,
        io_SIR_o        => open,
        io_IEN_o        => open,
        io_ENF_o        => open,
        io_POPIO_o      => open,
        io_STF_o        => open,
        io_IAK_o        => open,
        io_CLF_o        => open,
        io_STC_o        => open,
        io_CLC_o        => open,
        io_CRS_o        => open,
        io_SFC_o        => open,
        io_SFS_o        => open,
        -- The CPU receives these backplane signals from the interface:
        io_PRL_i        => '0',
        io_SRQ_i        => '0',
        io_FLG_i        => '0',
        io_IRQ_i        => '0',
        io_SKF_i        => '0'
    );

    --COREMEM_i : TESTMEM2100A
    COREMEM_i : COREMEM
        port map(
            Clock       => clk,
            ClockEn     => '1',
            Reset       => '0',
            WE          => cpu_write,
            Address     => cpu_addr(12 downto 0),
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
        cpu_run <= '0';
        SRH <= '0';
        reset <= '0' after 333 ns;
        wait for 500 ns;
        io_to_cpu <= std_logic_vector(resize(unsigned'(O"00100"), 16)); -- initial address
        load_addr <= '1';
        wait for 101 ns;
        load_addr <= '0';
        wait for 101 ns;
        io_to_cpu <= X"0010"; -- initial tty
        wait for 101 ns;
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
        SRH <= '1';
        wait;
    end process;

end architecture logic;