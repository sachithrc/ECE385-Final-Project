//-------------------------------------------------------------------------
//    mb_usb_hdmi_top.sv                                                 --
//    Zuofu Cheng                                                        --
//    2-29-24                                                            --
//                                                                       --
//                                                                       --
//    Spring 2024 Distribution                                           --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------


module mb_usb_hdmi_top(
    input logic Clk,
    input logic reset_rtl_0,
   
    //USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
   
    //UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
   
    //HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
       
    //HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB
);
   
    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk, clk_100MHz;
    logic locked;
    logic [9:0] drawX, drawY, ballxsig, ballysig, ballsizesig;

    logic hsync, vsync, vde;
    logic [3:0] red, green, blue;
    logic reset_ah;
   
    // Shape generator signals
    logic shape_edge;
    logic [1:0] shape_select;
   
    assign reset_ah = reset_rtl_0;
    
    // Use first two keycodes to select shape
    // 00: None, 01: Circle, 10: Square, 11: Triangle
   
   
    //Keycode HEX drivers
    hex_driver HexA (
        .clk(Clk),
        .reset(reset_ah),
        .in(),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
   
    hex_driver HexB (
        .clk(Clk),
        .reset(reset_ah),
        .in(),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );
   
    mb_block mb_block_i (
        .clk_100MHz(Clk),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(),
        .gpio_usb_keycode_1_tri_o(),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_ah), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
       
    //clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk)
    );
   
    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        //Reset is active LOW
        .rst(reset_ah),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
       
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
       
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),        
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );

    // Shape generator - directly using keyboard input to select shapes
    shape_generator #(
        .CX(320),   // Center X position
        .CY(240),   // Center Y position
        .R(100),    // Radius for circle
        .S(80)      // Size for square and triangle
    ) shape_gen (
        .clk(clk_25MHz),
        .reset(reset_ah),
        .shape_select(shape_select),  // Connect to keycode bits
        .drawX(drawX),
        .drawY(drawY),
        .vde(vde),
        .shape_edge(shape_edge)
    );
    
    // Modified color mapper that uses shape_edge instead of ball position
    shape_color_mapper color_instance(
        .shape_edge(shape_edge),
        .DrawX(drawX),
        .DrawY(drawY),
        .Red(red),
        .Green(green),
        .Blue(blue)
    );
   
endmodule



