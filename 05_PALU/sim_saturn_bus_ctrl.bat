@echo off
set path=c:\tools\iverilog\bin
iverilog -o tb_saturn_bus_ctrl.out -D SIMULATOR=1 tb_saturn_bus_ctrl.v saturn_bus_ctrl.v
if errorlevel == 1 goto error
vvp tb_saturn_bus_ctrl.out
:error