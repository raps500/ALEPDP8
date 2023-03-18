@echo off
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
rem set path=c:\tools\ghdl\bin;c:\tools\ghdl-0.35\bin;C:\tools\mingw-w64\x86_64-8.1.0-posix-seh-rt_v6-rev0\mingw64\bin;C:\tools\mingw-w64\msys2_64\usr\bin
echo --
echo --
echo -- PDP-8A VHDL Test bench
echo --
echo --
echo --
echo Analyze Disassembler PDP8A
ghdl -a --ieee=synopsys --std=08 ..\rtl\ALEPDP8DIS.vhdl
if errorlevel == 1 goto error
echo Analyze ALEPDP8CPU
ghdl -a --ieee=synopsys --std=08 ..\rtl\ALEPDP8CPU.vhdl
if errorlevel == 1 goto error
echo Analyze RAM
ghdl -a --ieee=synopsys --std=08 ..\..\firmware\TESTMEM.vhdl
rem ghdl -a --ieee=synopsys --std=08 ..\..\firmware\prepare.vhdl
rem ghdl -a --ieee=synopsys --std=08 ..\..\firmware\24317-16001.vhdl
rem ghdl -a --ieee=synopsys --std=08 ..\..\firmware\24316-18001.vhdl
rem ghdl -a --ieee=synopsys --std=08 ..\..\firmware\24315-18001.vhdl
if errorlevel == 1 goto error
echo Analyze TB
ghdl -a --ieee=synopsys --std=08 PDP8_tb.vhdl
if errorlevel == 1 goto error
echo Elaborate phase
ghdl -e --ieee=synopsys --std=08 PDP8_tb
echo Run simulation
if errorlevel == 1 goto error
ghdl -r --ieee=synopsys --std=08 PDP8_tb --vcd=PDP8_tb.vcd --stop-time=2us
:error
