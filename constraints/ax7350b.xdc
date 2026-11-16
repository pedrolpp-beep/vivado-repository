###############################################################################
# AX7350B - 30 MHz GTX TX
# Device: XC7Z035-2FFG676
###############################################################################

# Botão de start
set_property PACKAGE_PIN H7 [get_ports btn_start]
set_property IOSTANDARD LVCMOS15 [get_ports btn_start]

# Botão de stop
set_property PACKAGE_PIN H8 [get_ports btn_stop]
set_property IOSTANDARD LVCMOS15 [get_ports btn_stop]

set_false_path -from [get_ports btn_start]
set_false_path -from [get_ports btn_stop]

# LED de indicação do envio do sinal
set_property PACKAGE_PIN E5 [get_ports led_idle]
set_property IOSTANDARD LVCMOS15 [get_ports led_idle]

###############################################################################
# 1) System clock
# On-board PL oscillator: 50 MHz
###############################################################################

set_property PACKAGE_PIN J14 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS18 [get_ports sys_clk]

create_clock -name sys_clk \
    -period 20.000 \
    [get_ports sys_clk]


###############################################################################
# 2) GTX reference clock
# MGTREFCLK1 of BANK 111
# P = AA6
# N = AA5
# Frequency = 156.25 MHz
###############################################################################

set_property PACKAGE_PIN AA6 [get_ports gt_refclk_p]
set_property PACKAGE_PIN AA5 [get_ports gt_refclk_n]

create_clock -name gt_refclk_156m25 \
    -period 6.400 \
    [get_ports gt_refclk_p]


###############################################################################
# 3) GTX physical location
# Selected in the 7-Series Transceivers Wizard:
# GTX_X0Y11
#
# Dedicated TX pins:
#   TXP -> AC2 -> SMA_TX_P
#   TXN -> AC1 -> SMA_TX_N
#
# Do NOT assign AC1/AC2 as normal PACKAGE_PIN constraints.
###############################################################################

set_property LOC GTXE2_CHANNEL_X0Y11 \
    [get_cells -hierarchical \
     -filter {REF_NAME == GTXE2_CHANNEL && NAME =~ *gtxe2_i}]