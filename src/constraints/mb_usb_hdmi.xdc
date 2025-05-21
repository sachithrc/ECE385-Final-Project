# Clock (100 MHz)
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports Clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports Clk]

# Reset button (active high)
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS25} [get_ports reset_rtl_0]

# USB signals
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS25} [get_ports {gpio_usb_int_tri_i[0]}]
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS25} [get_ports gpio_usb_rst_tri_o]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS25} [get_ports usb_spi_miso]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS25} [get_ports usb_spi_mosi]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS25} [get_ports usb_spi_sclk]
set_property -dict {PACKAGE_PIN F5 IOSTANDARD LVCMOS25} [get_ports usb_spi_ss]

# UART
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS25} [get_ports uart_rtl_0_rxd]
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVCMOS25} [get_ports uart_rtl_0_txd]

# HDMI output
set_property -dict {PACKAGE_PIN V17 IOSTANDARD TMDS_33} [get_ports hdmi_tmds_clk_n]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD TMDS_33} [get_ports hdmi_tmds_clk_p]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD TMDS_33} [get_ports {hdmi_tmds_data_n[0]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD TMDS_33} [get_ports {hdmi_tmds_data_n[1]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD TMDS_33} [get_ports {hdmi_tmds_data_n[2]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD TMDS_33} [get_ports {hdmi_tmds_data_p[0]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD TMDS_33} [get_ports {hdmi_tmds_data_p[1]}]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD TMDS_33} [get_ports {hdmi_tmds_data_p[2]}]

# HEX Displays
# HEX A
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS25} [get_ports {hex_gridA[0]}]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS25} [get_ports {hex_gridA[1]}]
set_property -dict {PACKAGE_PIN C3 IOSTANDARD LVCMOS25} [get_ports {hex_gridA[2]}]
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS25} [get_ports {hex_gridA[3]}]
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS25} [get_ports {hex_segA[0]}]
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS25} [get_ports {hex_segA[1]}]
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS25} [get_ports {hex_segA[2]}]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS25} [get_ports {hex_segA[3]}]
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVCMOS25} [get_ports {hex_segA[4]}]
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVCMOS25} [get_ports {hex_segA[5]}]
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS25} [get_ports {hex_segA[6]}]
set_property -dict {PACKAGE_PIN B5 IOSTANDARD LVCMOS25} [get_ports {hex_segA[7]}]

# HEX B
set_property -dict {PACKAGE_PIN E4 IOSTANDARD LVCMOS25} [get_ports {hex_gridB[0]}]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS25} [get_ports {hex_gridB[1]}]
set_property -dict {PACKAGE_PIN F5 IOSTANDARD LVCMOS25} [get_ports {hex_gridB[2]}]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS25} [get_ports {hex_gridB[3]}]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS25} [get_ports {hex_segB[0]}]
set_property -dict {PACKAGE_PIN G5 IOSTANDARD LVCMOS25} [get_ports {hex_segB[1]}]
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS25} [get_ports {hex_segB[2]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS25} [get_ports {hex_segB[3]}]
set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS25} [get_ports {hex_segB[4]}]
set_property -dict {PACKAGE_PIN H3 IOSTANDARD LVCMOS25} [get_ports {hex_segB[5]}]
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS25} [get_ports {hex_segB[6]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS25} [get_ports {hex_segB[7]}] 