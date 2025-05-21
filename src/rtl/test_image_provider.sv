module test_image_provider (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [1:0]  image_select, // 00: circle, 01: square, 10: triangle, 11: custom
    output logic [7:0]  pixel_data,
    output logic        pixel_valid,
    output logic        frame_start,
    output logic        frame_done
);
    // Parameters
    localparam IMG_SIZE = 60;
    localparam IMG_PIXELS = IMG_SIZE * IMG_SIZE;
    
    // ROMs to store the test images
    logic [7:0] circle_rom [0:IMG_PIXELS-1];
    logic [7:0] square_rom [0:IMG_PIXELS-1];
    logic [7:0] triangle_rom [0:IMG_PIXELS-1];
    logic [7:0] custom_rom [0:IMG_PIXELS-1];
    
    // Counter to keep track of which pixel we're outputting
    logic [11:0] pixel_counter;
    
    // State machine
    typedef enum logic [1:0] {IDLE, START_FRAME, SENDING, DONE} state_t;
    state_t state;
    
    // Initialize ROMs with test images
    initial begin
        $readmemh("circle_image.hex", circle_rom);
        $readmemh("square_image.hex", square_rom);
        $readmemh("triangle_image.hex", triangle_rom);
        $readmemh("custom_image.hex", custom_rom);
    end
    
    // State machine and counter logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pixel_counter <= '0;
            pixel_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_done <= 1'b0;
            pixel_data <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    frame_done <= 1'b0;
                    pixel_valid <= 1'b0;
                    if (start) begin
                        state <= START_FRAME;
                        pixel_counter <= '0;
                    end
                end
                
                START_FRAME: begin
                    frame_start <= 1'b1;
                    pixel_valid <= 1'b0;
                    state <= SENDING;
                end
                
                SENDING: begin
                    frame_start <= 1'b0;
                    pixel_valid <= 1'b1;
                    
                    // Select the image data based on image_select
                    case (image_select)
                        2'b00: pixel_data <= circle_rom[pixel_counter];
                        2'b01: pixel_data <= square_rom[pixel_counter];
                        2'b10: pixel_data <= triangle_rom[pixel_counter];
                        2'b11: pixel_data <= custom_rom[pixel_counter];
                    endcase
                    
                    if (pixel_counter == IMG_PIXELS-1) begin
                        state <= DONE;
                        pixel_valid <= 1'b0;
                    end else begin
                        pixel_counter <= pixel_counter + 1'b1;
                    end
                end
                
                DONE: begin
                    frame_done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule 