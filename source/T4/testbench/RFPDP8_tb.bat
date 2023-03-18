@echo off
echo
echo  RRRRRR  FFFFFFF PPPPPP  DDDDD   PPPPPP   8888   
echo   RR  RR  FF   F  PP  PP  DD DD   PP  PP 88  88  
echo   RR  RR  FF F    PP  PP  DD  DD  PP  PP 88  88
echo   RRRRR   FFFF    PPPPP   DD  DD  PPPPP   8888
echo   RR RR   FF F    PP      DD  DD  PP     88  88
echo   RR  RR  FF      PP      DD DD   PP     88  88
echo  RRR  RR FFFF    PPPP    DDDDD   PPPP     8888
echo Analyze RFPDP8
ghdl -a --ieee=synopsys --std=08 ..\rtl\RFPDP8.vhdl
if errorlevel == 1 goto error
echo Analyze TB
ghdl -a --ieee=synopsys --std=08 RFPDP8_tb.vhdl
if errorlevel == 1 goto error
echo Elaborate phase
ghdl -e --ieee=synopsys --std=08 RFPDP8_tb
echo Run simulation
if errorlevel == 1 goto error
ghdl -r --ieee=synopsys --std=08 RFPDP8_tb --vcd=RFPDP8_tb.vcd --stop-time=102us
:error
