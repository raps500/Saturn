@echo off
set path=c:\tools\iverilog\bin
iverilog -o tb_dogm240.out -D SIMULATOR=1 tb_dogm240.v dogm240.v
if errorlevel == 1 goto error
vvp tb_dogm240.out
:error