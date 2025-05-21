// Top-level module that integrates shape detector with HDMI output
module mb_usb_hdmi_top (
    input  logic        clk_100MHz,   // 100 MHz system clock
    input  logic        reset_n,      // Active low reset
    input  logic [1:0]  image_select, // 00: none, 01: circle, 10: square, 11: triangle
    
    // HDMI outputs
    output logic        hdmi_clk,     // HDMI clock
    output logic        hdmi_hsync,   // HDMI horizontal sync
    output logic        hdmi_vsync,   // HDMI vertical sync
    output logic        hdmi_active,  // HDMI active video
    output logic [3:0]  hdmi_red,     // HDMI red data
    output logic [3:0]  hdmi_green,   // HDMI green data
    output logic [3:0]  hdmi_blue     // HDMI blue data
);

    // Internal signals
    logic        clk_25MHz;           // 25 MHz pixel clock for VGA
    logic        reset;               // Active high reset
    
    // VGA controller signals
    logic [9:0]  drawX, drawY;        // Current pixel coordinates
    logic        vga_hsync, vga_vsync;
    logic        vga_active;
    logic        vga_sync;
    
    // Shape generator signals
    logic        shape_edge;          // Shape outline pixel
    
    // Reset conversion (active-low to active-high)
    assign reset = ~reset_n;
    
    // Clock divider for 25MHz pixel clock (from 100MHz)
    logic [1:0] clk_div_counter = 0;
    always_ff @(posedge clk_100MHz or posedge reset) begin
        if (reset)
            clk_div_counter <= 0;
        else
            clk_div_counter <= clk_div_counter + 1;
    end
    assign clk_25MHz = clk_div_counter[1]; // Divide by 4 to get 25MHz
    
    // VGA controller
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset),
        .hs(vga_hsync),
        .vs(vga_vsync),
        .active_nblank(vga_active),
        .sync(vga_sync),
        .drawX(drawX),
        .drawY(drawY)
    );
    
    // Shape generator - directly using image_select instead of neural network output
    shape_generator #(
        .CX(320),   // Center X position
        .CY(240),   // Center Y position
        .R(100),    // Radius for circle
        .S(80)      // Size for square and triangle
    ) shape_gen (
        .clk(clk_25MHz),
        .reset(reset),
        .shape_select(image_select),  // Directly connect the switches
        .drawX(drawX),
        .drawY(drawY),
        .vde(vga_active),
        .shape_edge(shape_edge)
    );
    
    // Color mapper - converts shape outline to colors
    color_mapper color_map (
        .shape_edge(shape_edge),
        .DrawX(drawX),
        .DrawY(drawY),
        .Red(hdmi_red),
        .Green(hdmi_green),
        .Blue(hdmi_blue)
    );
    
    // Connect VGA signals to HDMI outputs
    assign hdmi_clk = clk_25MHz;
    assign hdmi_hsync = vga_hsync;
    assign hdmi_vsync = vga_vsync;
    assign hdmi_active = vga_active;

endmodule 