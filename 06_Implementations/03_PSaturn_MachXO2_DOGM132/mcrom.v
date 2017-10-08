/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.9.0.99.2 */
/* Module Version: 5.4 */
/* C:\lscc\diamond\3.9_x64\ispfpga\bin\nt64\scuba.exe -w -n mcrom -lang verilog -synth synplify -bus_exp 7 -bb -arch xo2c00 -type bram -wp 00 -rp 1100 -addr_width 9 -data_width 32 -num_rows 512 -outdata REGISTERED -cascade -1 -resetmode SYNC -sync_reset -memfile c:/02_elektronik/041_1lf2/10_public/06_implementations/03_psaturn_machxo2_dogm132/mc_tbl.bin -memformat bin  */
/* Sat Oct 07 14:39:41 2017 */


`timescale 1 ns / 1 ps
module mcrom (Address, OutClock, OutClockEn, Reset, Q)/* synthesis NGD_DRC_MASK=1 */;
    input wire [8:0] Address;
    input wire OutClock;
    input wire OutClockEn;
    input wire Reset;
    output wire [31:0] Q;

    wire scuba_vhi;
    wire scuba_vlo;

    defparam mcrom_0_0_1.INIT_DATA = "STATIC" ;
    defparam mcrom_0_0_1.ASYNC_RESET_RELEASE = "SYNC" ;
    defparam mcrom_0_0_1.INITVAL_1F = "0x000000000000000000000B000000000B058000002070220300271382713808642082400060200200" ;
    defparam mcrom_0_0_1.INITVAL_1E = "0x20500205002050020501186C2182C020702203001048010481086420824008440084410F0780F078" ;
    defparam mcrom_0_0_1.INITVAL_1D = "0x2070220300184C0184C1186C2182C0186C2182C02070220300271382713808642082400060200200" ;
    defparam mcrom_0_0_1.INITVAL_1C = "0x20500205002050020501186C2182C020702203001048010481086420824008440084410F0780F078" ;
    defparam mcrom_0_0_1.INITVAL_1B = "0x2070220300184C0184C1186C2182C0186C2182C02874228340186C2182C030782303802070220300" ;
    defparam mcrom_0_0_1.INITVAL_1A = "0x10682102800864208240104801028008440082400B05800000000000CCA60C8A43C8E4151A800000" ;
    defparam mcrom_0_0_1.INITVAL_19 = "0x2874228340186C2182C0307823038020702203001068210280086420824010480102800844008240" ;
    defparam mcrom_0_0_1.INITVAL_18 = "0x186C2182C000000000000060200200207022030000000000000000000000140A00C0600844000000" ;
    defparam mcrom_0_0_1.INITVAL_17 = "0x1188C1188C1168A1128811E8E11A8C1168A1128809E4E09A4C0964A0924809E4E09A4C0964A09248" ;
    defparam mcrom_0_0_1.INITVAL_16 = "0x0844208442084420844208040080400804008040000000000000000000000000000000186C2182C0" ;
    defparam mcrom_0_0_1.INITVAL_15 = "0x000000000020702203000000000000186C2182C014C00084660CE001CC0000067000000CA6508442" ;
    defparam mcrom_0_0_1.INITVAL_14 = "0x001D00CFD008482384C208080380C000058000003B1D83B1183B1D83B1221C6E2000000000000000" ;
    defparam mcrom_0_0_1.INITVAL_13 = "0x381C000402381C000000381C000402381C000000381C000402381C000000381C000402381C000000" ;
    defparam mcrom_0_0_1.INITVAL_12 = "0x146A208442146A208040146A208442146A20804011E8E11A8C1168A1128811E8E11A8C1168A11288" ;
    defparam mcrom_0_0_1.INITVAL_11 = "0x09E4E09A4C0964A0924809E4E09A4C0964A092480844208442084420844208040080400804008040" ;
    defparam mcrom_0_0_1.INITVAL_10 = "0x0000024CE6148420C8780C242000000000000000385C0385C1387C2383C030580305813078230380" ;
    defparam mcrom_0_0_1.INITVAL_0F = "0x00000000000000000000042000000000426000002070220300186820820018682082001868208200" ;
    defparam mcrom_0_0_1.INITVAL_0E = "0x18682082401848008401307823038010602102401868208200004000040100602002000060200200" ;
    defparam mcrom_0_0_1.INITVAL_0D = "0x30782303801848008401186820820010602102402070220300186820820018682082001868208200" ;
    defparam mcrom_0_0_1.INITVAL_0C = "0x18682082401848008401307823038010602102401868208200004000040100602002000060200200" ;
    defparam mcrom_0_0_1.INITVAL_0B = "0x30782303801848008401186820820010602102401000010040100001004010000100401000010040" ;
    defparam mcrom_0_0_1.INITVAL_0A = "0x2814028140281402814018080100401808010040042210000000000381C03C9E43C9E43D1E800000" ;
    defparam mcrom_0_0_1.INITVAL_09 = "0x10000100401000010040100001004010000100402814028140281402814018080100401808010040" ;
    defparam mcrom_0_0_1.INITVAL_08 = "0x00602002000000000000006020020018682082000000000000000000000000400004000402000000" ;
    defparam mcrom_0_0_1.INITVAL_07 = "0x00402004020040200402000000000000000000000040200402004020040200000000000000000000" ;
    defparam mcrom_0_0_1.INITVAL_06 = "0x01E0E01A0C0160A0120801E0E01A0C0160A012080000000000000000000000000000001868208200" ;
    defparam mcrom_0_0_1.INITVAL_05 = "0x0000000000387C2383C00000000000387C2383C01040004C02100001040000002000000040004A25" ;
    defparam mcrom_0_0_1.INITVAL_04 = "0x000A018020385C2385C2381C0381C00000000000046230462304422045E23C7E2000000000000000" ;
    defparam mcrom_0_0_1.INITVAL_03 = "0x00402000000000000000004020000000000000000040200000000000000000402000000000000000" ;
    defparam mcrom_0_0_1.INITVAL_02 = "0x10482046220000004622104820462200000046221048210482104821048200000000000000000000" ;
    defparam mcrom_0_0_1.INITVAL_01 = "0x004020040200402004020000000000000000000001E0E01A0C0160A0120801E0E01A0C0160A01208" ;
    defparam mcrom_0_0_1.INITVAL_00 = "0x0000034DA6104A400424004210000000000000001848008401106021024018480084011060210240" ;
    defparam mcrom_0_0_1.CSDECODE_B = "0b000" ;
    defparam mcrom_0_0_1.CSDECODE_A = "0b000" ;
    defparam mcrom_0_0_1.WRITEMODE_B = "NORMAL" ;
    defparam mcrom_0_0_1.WRITEMODE_A = "NORMAL" ;
    defparam mcrom_0_0_1.GSR = "ENABLED" ;
    defparam mcrom_0_0_1.RESETMODE = "SYNC" ;
    defparam mcrom_0_0_1.REGMODE_B = "OUTREG" ;
    defparam mcrom_0_0_1.REGMODE_A = "OUTREG" ;
    defparam mcrom_0_0_1.DATA_WIDTH_B = 9 ;
    defparam mcrom_0_0_1.DATA_WIDTH_A = 9 ;
    DP8KC mcrom_0_0_1 (.DIA8(scuba_vlo), .DIA7(scuba_vlo), .DIA6(scuba_vlo), 
        .DIA5(scuba_vlo), .DIA4(scuba_vlo), .DIA3(scuba_vlo), .DIA2(scuba_vlo), 
        .DIA1(scuba_vlo), .DIA0(scuba_vlo), .ADA12(scuba_vlo), .ADA11(Address[8]), 
        .ADA10(Address[7]), .ADA9(Address[6]), .ADA8(Address[5]), .ADA7(Address[4]), 
        .ADA6(Address[3]), .ADA5(Address[2]), .ADA4(Address[1]), .ADA3(Address[0]), 
        .ADA2(scuba_vlo), .ADA1(scuba_vlo), .ADA0(scuba_vlo), .CEA(OutClockEn), 
        .OCEA(OutClockEn), .CLKA(OutClock), .WEA(scuba_vlo), .CSA2(scuba_vlo), 
        .CSA1(scuba_vlo), .CSA0(scuba_vlo), .RSTA(Reset), .DIB8(scuba_vlo), 
        .DIB7(scuba_vlo), .DIB6(scuba_vlo), .DIB5(scuba_vlo), .DIB4(scuba_vlo), 
        .DIB3(scuba_vlo), .DIB2(scuba_vlo), .DIB1(scuba_vlo), .DIB0(scuba_vlo), 
        .ADB12(scuba_vhi), .ADB11(Address[8]), .ADB10(Address[7]), .ADB9(Address[6]), 
        .ADB8(Address[5]), .ADB7(Address[4]), .ADB6(Address[3]), .ADB5(Address[2]), 
        .ADB4(Address[1]), .ADB3(Address[0]), .ADB2(scuba_vlo), .ADB1(scuba_vlo), 
        .ADB0(scuba_vlo), .CEB(OutClockEn), .OCEB(OutClockEn), .CLKB(OutClock), 
        .WEB(scuba_vlo), .CSB2(scuba_vlo), .CSB1(scuba_vlo), .CSB0(scuba_vlo), 
        .RSTB(Reset), .DOA8(Q[8]), .DOA7(Q[7]), .DOA6(Q[6]), .DOA5(Q[5]), 
        .DOA4(Q[4]), .DOA3(Q[3]), .DOA2(Q[2]), .DOA1(Q[1]), .DOA0(Q[0]), 
        .DOB8(Q[17]), .DOB7(Q[16]), .DOB6(Q[15]), .DOB5(Q[14]), .DOB4(Q[13]), 
        .DOB3(Q[12]), .DOB2(Q[11]), .DOB1(Q[10]), .DOB0(Q[9]))
             /* synthesis MEM_LPC_FILE="mcrom.lpc" */
             /* synthesis MEM_INIT_FILE="mc_tbl.bin" */;

    VHI scuba_vhi_inst (.Z(scuba_vhi));

    VLO scuba_vlo_inst (.Z(scuba_vlo));

    defparam mcrom_0_1_0.INIT_DATA = "STATIC" ;
    defparam mcrom_0_1_0.ASYNC_RESET_RELEASE = "SYNC" ;
    defparam mcrom_0_1_0.INITVAL_1F = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_1E = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_1D = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_1C = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_1B = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_1A = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_19 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_18 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_17 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_16 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_15 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_14 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_13 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_12 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_11 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_10 = "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_0F = "0x00000000000000000000020000000000000000000201002010020100201002211022110221102211" ;
    defparam mcrom_0_1_0.INITVAL_0E = "0x02010020100201002010020100201002010020100201002010020100201002010020100201002010" ;
    defparam mcrom_0_1_0.INITVAL_0D = "0x02010020100201002010020100201002010020100301803018030180301803219032190321903219" ;
    defparam mcrom_0_1_0.INITVAL_0C = "0x03018030180301803018030180301803018030180301803018030180301803018030180301803018" ;
    defparam mcrom_0_1_0.INITVAL_0B = "0x03018030180301803018030180301803018030180341A0341A0341A0341A0341A0341A0341A0341A" ;
    defparam mcrom_0_1_0.INITVAL_0A = "0x0341A0341A0341A0341A0341A0341A0341A0341A0201000000000000040201E0F0180F0060000000" ;
    defparam mcrom_0_1_0.INITVAL_09 = "0x02412024120241202412024120241202412024120241202412024120241202412024120241202412" ;
    defparam mcrom_0_1_0.INITVAL_08 = "0x03A1D03A1D000000000003C1E03C1E03A1D03A1D0000000000000000000002010020100201000000" ;
    defparam mcrom_0_1_0.INITVAL_07 = "0x03018030180301803018030180301803018030180301803018030180301803018030180301803018" ;
    defparam mcrom_0_1_0.INITVAL_06 = "0x03018030180301803018030180301803018030180000000000000000000000000000000321903219" ;
    defparam mcrom_0_1_0.INITVAL_05 = "0x00000000000301803018000000000003018030180000000000000000200000010000000180C01000" ;
    defparam mcrom_0_1_0.INITVAL_04 = "0x000120201201E0F0180F01E0F0180F00014000000240E00C100240E00C1002010000000000000000" ;
    defparam mcrom_0_1_0.INITVAL_03 = "0x02C1602E1702C1602E170341A0361B0341A0361B00C0600E0700C0600E0702412026130241202613" ;
    defparam mcrom_0_1_0.INITVAL_02 = "0x02010020100201002010020100201002010020100381C0381C0381C0381C0381C0381C0381C0381C" ;
    defparam mcrom_0_1_0.INITVAL_01 = "0x0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C0381C" ;
    defparam mcrom_0_1_0.INITVAL_00 = "0x00000000000100801008020100201002010020100301803018030180301803018030180301803018" ;
    defparam mcrom_0_1_0.CSDECODE_B = "0b000" ;
    defparam mcrom_0_1_0.CSDECODE_A = "0b000" ;
    defparam mcrom_0_1_0.WRITEMODE_B = "NORMAL" ;
    defparam mcrom_0_1_0.WRITEMODE_A = "NORMAL" ;
    defparam mcrom_0_1_0.GSR = "ENABLED" ;
    defparam mcrom_0_1_0.RESETMODE = "SYNC" ;
    defparam mcrom_0_1_0.REGMODE_B = "OUTREG" ;
    defparam mcrom_0_1_0.REGMODE_A = "OUTREG" ;
    defparam mcrom_0_1_0.DATA_WIDTH_B = 9 ;
    defparam mcrom_0_1_0.DATA_WIDTH_A = 9 ;
    DP8KC mcrom_0_1_0 (.DIA8(scuba_vlo), .DIA7(scuba_vlo), .DIA6(scuba_vlo), 
        .DIA5(scuba_vlo), .DIA4(scuba_vlo), .DIA3(scuba_vlo), .DIA2(scuba_vlo), 
        .DIA1(scuba_vlo), .DIA0(scuba_vlo), .ADA12(scuba_vlo), .ADA11(Address[8]), 
        .ADA10(Address[7]), .ADA9(Address[6]), .ADA8(Address[5]), .ADA7(Address[4]), 
        .ADA6(Address[3]), .ADA5(Address[2]), .ADA4(Address[1]), .ADA3(Address[0]), 
        .ADA2(scuba_vlo), .ADA1(scuba_vlo), .ADA0(scuba_vlo), .CEA(OutClockEn), 
        .OCEA(OutClockEn), .CLKA(OutClock), .WEA(scuba_vlo), .CSA2(scuba_vlo), 
        .CSA1(scuba_vlo), .CSA0(scuba_vlo), .RSTA(Reset), .DIB8(scuba_vlo), 
        .DIB7(scuba_vlo), .DIB6(scuba_vlo), .DIB5(scuba_vlo), .DIB4(scuba_vlo), 
        .DIB3(scuba_vlo), .DIB2(scuba_vlo), .DIB1(scuba_vlo), .DIB0(scuba_vlo), 
        .ADB12(scuba_vhi), .ADB11(Address[8]), .ADB10(Address[7]), .ADB9(Address[6]), 
        .ADB8(Address[5]), .ADB7(Address[4]), .ADB6(Address[3]), .ADB5(Address[2]), 
        .ADB4(Address[1]), .ADB3(Address[0]), .ADB2(scuba_vlo), .ADB1(scuba_vlo), 
        .ADB0(scuba_vlo), .CEB(OutClockEn), .OCEB(OutClockEn), .CLKB(OutClock), 
        .WEB(scuba_vlo), .CSB2(scuba_vlo), .CSB1(scuba_vlo), .CSB0(scuba_vlo), 
        .RSTB(Reset), .DOA8(Q[26]), .DOA7(Q[25]), .DOA6(Q[24]), .DOA5(Q[23]), 
        .DOA4(Q[22]), .DOA3(Q[21]), .DOA2(Q[20]), .DOA1(Q[19]), .DOA0(Q[18]), 
        .DOB8(), .DOB7(), .DOB6(), .DOB5(), .DOB4(Q[31]), .DOB3(Q[30]), 
        .DOB2(Q[29]), .DOB1(Q[28]), .DOB0(Q[27]))
             /* synthesis MEM_LPC_FILE="mcrom.lpc" */
             /* synthesis MEM_INIT_FILE="mc_tbl.bin" */;



    // exemplar begin
    // exemplar attribute mcrom_0_0_1 MEM_LPC_FILE mcrom.lpc
    // exemplar attribute mcrom_0_0_1 MEM_INIT_FILE mc_tbl.bin
    // exemplar attribute mcrom_0_1_0 MEM_LPC_FILE mcrom.lpc
    // exemplar attribute mcrom_0_1_0 MEM_INIT_FILE mc_tbl.bin
    // exemplar end

endmodule