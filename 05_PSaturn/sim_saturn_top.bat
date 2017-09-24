@echo off
set path=c:\tools\iverilog\bin
iverilog -o tb_saturn_top.out -D SIMULATOR=1 tb_saturn_top.v saturn_top.v saturn_core.v saturn_decoder_sequencer.v saturn_alru.v saturn_bus_ctrl.v
if errorlevel == 1 goto error
vvp tb_saturn_top.out
:error