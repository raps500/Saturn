@echo off
set path=c:\tools\iverilog\bin
iverilog -o tb_saturn_alru.out -D SIMULATOR=1 tb_saturn_alru.v saturn_alru.v
if errorlevel == 1 goto error
vvp tb_saturn_alru.out
:error