--
-- Ale's PDP-8 
-- Main CPU block 
-- - Microcoded behavioral  CPU
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
		data_o          : out  std_logic_vector(11 downto 0);
        addr_o          : out  std_logic_vector(14 downto 0);
        read_n_o        : out std_logic;
        write_n_o       : out std_logic
    );
end entity APDP8CPU;


architecture logic of APDP8CPU is
    component E69 is
        port (
            addr_i          : in  std_logic_vector(4 downto 0);
            dis_n_i         : in  std_logic;
            data_o          : out std_logic_vector(7 downto 0)
        );
    end component E69;

    signal AC_DATA_L        : std_logic_vector(11 downto 0);    
    signal AC               : std_logic_vector(11 downto 0);    -- Accumulator
    signal AC_AC0           : std_logic;
    signal AC_AC11          : std_logic;
    signal AC_AUTO_L        : std_logic;
    signal AC_ZERO_L        : std_logic;
    signal AD_SUM           : std_logic_vector(11 downto 0);    
    signal CPMA_DIS_L       : std_logic;
    signal E42FF            : std_logic_vector(3 downto 0);    
    signal E69_addr         : std_logic_vector(4 downto 0);    
    signal E69_data         : std_logic_vector(7 downto 0);    
    signal IDI_AND_EN_L     : std_logic;
    signal IDI_ID3_AC_BUS_L : std_logic;
    signal IDI_ID3_MQ_BUS_L : std_logic;
    signal IDI_CPMA_BUS_L   : std_logic;
    signal IDI_CPMA_LOAD    : std_logic;
    signal IDI_PAGE_EN_L    : std_logic;
    signal IDI_MEM_START_L  : std_logic;
    signal IDI_MD_EN_L      : std_logic;
    signal IDI_MQ_CLR_EN_L  : std_logic;
    signal IDI_MQ_LD_EN_L   : std_logic;
    signal IDI_PAGE_EN_L    : std_logic;
    signal IDI_PC_EN_L      : std_logic;
    signal IDI_PC_LD_EN_L   : std_logic;
    signal ID2_BSW_L        : std_logic;
    signal ID2_LINK_BIT     : std_logic;
    signal ID2_PC_AC_MQ_CLK : std_logic; -- no real clock but a gate
    signal ID2_RL_EN        : std_logic;
    signal ID2_RR_EN        : std_logic;
    signal ID3_CLEAR_L      : std_logic;
    signal ID3_INIT_L       : std_logic;
    signal KEY_CONTROL_L    : std_logic;
    signal LA_ENABLE_L      : std_logic;
    signal MA_AD_ADD_IN     : std_logic_vector(11 downto 0);
    signal MA_MD_FF         : std_logic_vector(11 downto 0);
    signal MA_MD_L          : std_logic_vector(11 downto 0);
    signal MA_L             : std_logic_vector(11 downto 0);
    signal MQ               : std_logic_vector(11 downto 0);
    signal PC               : std_logic_vector(11 downto 0);
    signal TG1_TP2_H        : std_logic;
    signal TGI_TP4_H        : std_logic;
    signal TGI_TSI_L        : std_logic;
    signal TG2_MD_DIR_L     : std_logic;

begin

--             AA      CCCC  
--            AAAA    CC  CC      
--           AA  AA  CC
--           AA  AA  CC
--           AAAAAA  CC
--           AA  AA   CC  CC      
--           AA  AA    CCCC  
    --
    -- MA
    --
    --

    MA_MD: process(clk_i, rst_i)
    begin
        if rst = '1' then
            MA_MD_FF <= (others => '0');
        elsif rising_edge(clk_i) then
            if TG1_TP2_H = '1' then
                MA_MD_FF <= AD_SUM;
            end if;
        end if;
    end process MA_MD;
    MA_MD_L     <= MA_MD_FF when TG2_MD_DIR_L = '1' else X"FFF"; -- open collector...

    MA: process(clk_i, rst_i)
    begin
        if rst = '1' then
            MA_FF <= (others => '0');
        elsif rising_edge(clk_i) then
            if IDI_CPMA_LOAD = '1' then
                MA_FF <= AD_SUM;
            end if;
        end if;
    end process MA;
    MA_L        <= MA_FF when IDI_CPMA_BUS_L = '0' else X"FFF";

    MA_AD_ADD_IN( 4 downto 0)   <= MA_L when IDI_MA_EN_L and (MA_MD_L(4) or IDI_PAGE_EN_L) = '0' else "11111";
    MA_AD_ADD_IN(11 downto 5)   <= MA_L when IDI_MA_EN_L = '0' else "1111111";

    --
    -- AC
    --

    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            AC <= (others => '0');
        elsif rising_edge(clk_i)
            if ID2_PC_AC_MQ_CLK = '1' then
                if ID3_INIT_L = '0' then
                    AC <= (others => '0');
                else 
                    case (ID2_RL_EN & ID2_RR_EN) is
                        when "00" => null;
                        when "01" => AC <= AC(10 downto 0) & ID2_LINK_BIT;-- shift left
                        when "10" => AC <= ID2_LINK_BIT & AC(11 downto 1);-- shift right
                        when others => 
                            if ID2_BSW_L = '0' then -- E115, E107, E109
                                AC <= not (AD_SUM(5 downto 0) & AD_SUM(11 downto 6));
                            else
                                AC <= not AD_SUM(11 downto 0) ;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;
    AC_AUTO_L   <= '0' when AD_SUM(8 downto 0) = "111111111" else '1';
    AC_ZERO_L   <= '0' when AD_SUM = X"FFF" else '1';

    AC_AC0      <= AC(0);
    AC_AC11     <= AC(11);

    
    --
    -- MQ
    --

    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            MQ <= (others => '0');
        elsif rising_edge(clk_i)
            if ID2_PC_AC_MQ_CLK = '1' then
                if IDI_MQ_CLR_EN_L = '0' then
                    MQ <= (others => '0');
                elsif IDI_MQ_LD_EN_L = '0' then 
                    MQ <= AC;
                end if;
            end if;
        end if;
    end process;
    -- to produce AC_DATA_L three 8234 and three 8235 are used
    -- these are open collector and produce different outputs
    -- 8234                           8235
    -- S1 S0 : Out                    S1 S0 : Out
    -- -----------                    -----------
    --  0  0 :  not B  not MA_MD_L     0  0 : not A and B  not AC_AC and MQ
    --  0  1 :  not A  not AC_AC       0  1 : not A        not MQ
    --  1  0 :  not B  not MA_MD_L     1  0 : B            AC_AC
    --  1  1 :  hi-z                   1  1 : hi-z
    -- This results in :
    --
    -- IDI_AND_EN_L (S0)
    -- IDI_ID3_AC_BUS_L (S1 8234)
    -- IDI_ID3_MQ_BUS_L (S1 8235)
    -- IDI_ID3_MQ_BUS_L  IDI_ID3_AC_BUS_L  IDI_AND_EN_L : Out
    -- --------------------------------------------------------
    --                0                 0             0 : not usable
    --                0                 0             1 : not usable
    --                0                 1             0 : not usable
    --                0                 1             1 : not MQ
    --                1                 0             0 : not MA_MD_L and AC_AC
    --                1                 0             1 : not AC_AC
    --                1                 1             0 : not MA_MD_L and AC_AC
    --                1                 1             1 : hi-z
    --
    --
    AC_DATA_L <= not AC when  IDI_ID3_MQ_BUS_L = '1' and IDI_ID3_AC_BUS_L = '0' and  IDI_AND_EN_L = '1' else
                 not MQ when  IDI_ID3_MQ_BUS_L = '0' and IDI_ID3_AC_BUS_L = '1' and  IDI_AND_EN_L = '1' else
                 (not MA_MD_L) and AC when  IDI_ID3_MQ_BUS_L = '1' and IDI_ID3_AC_BUS_L = '0' and  IDI_AND_EN_L = '0' else
                 (not MA_MD_L) and AC when  IDI_ID3_MQ_BUS_L = '1' and IDI_ID3_AC_BUS_L = '1' and  IDI_AND_EN_L = '0' else
                    X"FFF";
    
--             AA    DDDDD   
--            AAAA    DD DD  
--           AA  AA   DD  DD
--           AA  AA   DD  DD
--           AAAAAA   DD  DD
--           AA  AA   DD DD
--           AA  AA  DDDDD
    -- the internal bus is nagated... 
    AD_SUM <= not std_logic_vecotr(unsigned(MA_AD_ADD_IN) + unsigned(AC_DATA_L) + unsigned(AD_C_OUT_L)) when IDI_DATA_COMP_L = '0' else 
              not std_logic_vecotr(unsigned(MA_AD_ADD_IN) + unsigned(not AC_DATA_L) + unsigned(AD_C_OUT_L));

    MA_AD_ADD_IN( 4 downto 0) <=    PC(4 downto 0) when IDI_PC_EN_L = '0' else
                                 MA_MD(4 downto 0) when IDI_MD_EN_L = '0' else "11111";
    MA_AD_ADD_IN(11 downto 5) <=    PC(11 downto 5) when IDI_PC_EN_L = '0' else
                                 MA_MD(11 downto 5) when IDI_MD_EN_L = '0' and IDI_PAGE_EN_L = '0' else "11111";

    process (clk_i, rst_i)
    begin
        if rst_i = '1' then 
            PC <= (others => '0');
        elsif rising_edge(clk_i)
            if IDI_PC_LD_EN_L = '0' then
                PC <= AD_SUM;
            end if;
        end if;
    end process;

--          IIII   DDDDD    IIII   
--           II     DD DD    II    
--           II     DD  DD   II    
--           II     DD  DD   II    
--           II     DD  DD   II    
--           II     DD DD    II    
--          IIII   DDDDD    IIII 

    IDI_MEM_START_L <= TGI_TSI_L or (not ( (not E42FF(0)) and (not E42FF(1)) ));
    KEY_CONTROL_L   <= not ( (not E42FF(0)) and (not E42FF(1)) );
    LA_ENABLE_L     <= E4FF(1); -- E55, E49
    
    -- E42
    process (clk_i, rst_i)
    begin
        if rst_i = '1' then 
            E42FF <= (others => '0');
        elsif rising_edge(clk_i)
            if ID3_CLEAR_L = '0' then
                E42FF <= "0000"; -- 3 bits are enough
            elsif TGI_TP4_H = '1' then
                E42FF <= (not CPMA_DIS_L) & '0' & E42FF(0) & '1';
            end if;
        end if;
    end process;
    -- E69 256x4 ROM 23078A1
    E69_addr    <= LA_ENABLE_L & KEY_CONTROL_L & BREAK_DATA_CONT_L & TGI_T0 & TGI_T1;
    E69_i : E69 
        port map (
            addr_i          => E69_addr,
            dis_n_i         => IDI_DMA_L,
            data_o          => E69_data
        );




end architecture logic;



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity E69 is
	port (
        addr_i          : in  std_logic_vector(4 downto 0);
        dis_n_i         : in  std_logic;
        data_o          : out std_logic_vector(7 downto 0)
    );
end entity E69;

architecture logic of E69 is
    type rom_t is array(natural range 0 to 31) of std_logic_vector(7 downto 0);
    constant romdata : rom_t := (
        "11111111",
        "01011111",
        "00111111",
        "01011111",
        "11111111",
        "11111111",
        "00111111",
        "11111111",
        "10101011",
        "01111111",
        "11111100",
        "11111111",
        "11111100",
        "01111111",
        "00111111",
        "11111000",
        "11111011",
        "01111111",
        "00111111",
        "11110111",
        "11111011",
        "01111111",
        "11111100",
        "11110111",
        "11111111",
        "11111111",
        "00111100",
        "11111111",
        "11111111",
        "11111111",
        "11111100",
        "11111111");
begin
    data_o <= romdata(to_integer(unsigned(addr_i))) when dis_n_i = '0' else "11111111";

end architecture logic;