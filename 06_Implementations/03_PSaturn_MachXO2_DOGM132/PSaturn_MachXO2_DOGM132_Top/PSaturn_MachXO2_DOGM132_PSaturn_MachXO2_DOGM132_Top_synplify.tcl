#-- Lattice Semiconductor Corporation Ltd.
#-- Synplify OEM project file

#device options
set_option -technology MACHXO2
set_option -part LCMXO2_7000ZE
set_option -package TG144C
set_option -speed_grade -1

#compilation/mapping options
set_option -symbolic_fsm_compiler true
set_option -resource_sharing true

#use verilog 2001 standard option
set_option -vlog_std v2001

#map options
set_option -frequency auto
set_option -maxfan 1000
set_option -auto_constrain_io 0
set_option -disable_io_insertion false
set_option -retiming false; set_option -pipe true
set_option -force_gsr false
set_option -compiler_compatible 0
set_option -dup false
set_option -frequency 1
set_option -default_enum_encoding default

#simulation options


#timing analysis options



#automatic place and route (vendor) options
set_option -write_apr_constraint 1

#synplifyPro options
set_option -fix_gated_and_generated_clocks 1
set_option -update_models_cp 0
set_option -resolve_multiple_driver 0


#-- add_file options
set_option -include_path {C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/03_PSaturn_MachXO2_DOGM132}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/02_Components/PSaturn_MachXO2_DOGM132.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/05_PSaturn/saturn_alru.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/05_PSaturn/saturn_bus_ctrl.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/05_PSaturn/saturn_core.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/05_PSaturn/saturn_decoder_sequencer.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/05_PSaturn/saturn_defs.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/02_Components/dogm132.v}
add_file -verilog {C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/03_PSaturn_MachXO2_DOGM132/mcrom.v}

#-- top module name
set_option -top_module PSaturn_MachXO2_DOGM132

#-- set result format/file last
project -result_file {C:/02_Elektronik/041_1LF2/10_Public/06_Implementations/03_PSaturn_MachXO2_DOGM132/PSaturn_MachXO2_DOGM132_Top/PSaturn_MachXO2_DOGM132_PSaturn_MachXO2_DOGM132_Top.edi}

#-- error message log file
project -log_file {PSaturn_MachXO2_DOGM132_PSaturn_MachXO2_DOGM132_Top.srf}

#-- set any command lines input by customer


#-- run Synplify with 'arrange HDL file'
project -run
