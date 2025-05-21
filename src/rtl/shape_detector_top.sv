module shape_detector_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  pixel_data,  // Input pixel data (grayscale)
    input  logic        pixel_valid, // Indicates valid pixel data
    input  logic        frame_start, // Indicates start of new frame
    output logic [1:0]  shape_type,  // 00: unknown, 01: circle, 10: square, 11: triangle
    output logic        result_valid // Indicates valid result
);

    // Parameters
    localparam IMG_SIZE  = 60;       // 60x60 input image
    localparam INPUT_SIZE = IMG_SIZE * IMG_SIZE;
    localparam H1_SIZE   = 64;      // Hidden layer 1 size (reduced from 256)
    localparam H2_SIZE   = 64;      // Hidden layer 2 size (reduced from 256)
    localparam H3_SIZE   = 64;      // Hidden layer 3 size (reduced from 256)
    localparam OUT_SIZE  = 3;        // Output classes (circle, square, triangle)
    
    // Internal signals
    logic [7:0] image_buffer [0:INPUT_SIZE-1];  // Buffer to store the input image
    logic [$clog2(INPUT_SIZE)-1:0] pixel_count; // Counter for incoming pixels
    logic processing_done;                     // Processing complete flag
    logic processing_active;                   // Processing in progress flag
    
    // Classification results
    logic signed [15:0] output_values [0:OUT_SIZE-1]; // Output values from the network
    logic signed [15:0] captured_outputs [0:OUT_SIZE-1]; // Captured stable output values
    logic [1:0] max_index;                           // Index of the maximum output value
    
    // State machine for image processing
    typedef enum logic [2:0] {
        IDLE,
        CAPTURE,
        PROCESS,
        CLASSIFY,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // State machine logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (frame_start)
                    next_state = CAPTURE;
            end
            
            CAPTURE: begin
                if (pixel_count == INPUT_SIZE-1 && pixel_valid)
                    next_state = PROCESS;
            end
            
            PROCESS: begin
                if (processing_active == 1'b0)  // Processing is done
                    next_state = CLASSIFY;
            end
            
            CLASSIFY: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Pixel counter logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= '0;
        end else if (current_state == IDLE && frame_start) begin
            pixel_count <= '0;
        end else if (current_state == CAPTURE && pixel_valid) begin
            pixel_count <= pixel_count + 1'b1;
        end
    end
    
    // Image buffer loading
    always_ff @(posedge clk) begin
        if (current_state == CAPTURE && pixel_valid) begin
            image_buffer[pixel_count] <= pixel_data;
        end
    end
    
    // Neural network module instance
    neural_network nn (
        .clk(clk),
        .rst_n(rst_n),
        .start(current_state == PROCESS),
        .image_data(image_buffer),
        .done(processing_done),
        .active(processing_active),
        .output_values(output_values)
    );
    
    // Debug monitor for neural network done signal
    always @(posedge clk) begin
        if (processing_done && !$past(processing_done)) begin
            $display("Time %0t: Neural network DONE signal received", $time);
            $display("Time %0t: Current output values: Circle=%d, Square=%d, Triangle=%d", 
                     $time, output_values[0], output_values[1], output_values[2]);
            
            // Capture stable output values for classification
            captured_outputs[0] <= output_values[0];
            captured_outputs[1] <= output_values[1];
            captured_outputs[2] <= output_values[2];
        end
    end
    
    // Output classification logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shape_type <= 2'b00;   // Unknown
            result_valid <= 1'b0;
        end else if (current_state == CLASSIFY) begin
            // Find the maximum value and its index
            logic signed [15:0] max_val;
            logic [1:0] max_idx;
            
            // Initialize with output 0 (but use 00 as unknown instead of 01 as circle)
            max_val = captured_outputs[0];
            max_idx = 2'd0;  // Start with unknown
            
            // Only assign circle (01) if it's actually the maximum
            if (captured_outputs[0] > max_val) begin
                max_val = captured_outputs[0];
                max_idx = 2'd1;  // 01: circle
            end
            
            if (captured_outputs[1] > max_val) begin
                max_val = captured_outputs[1];
                max_idx = 2'd2;  // 10: square
            end
            
            if (captured_outputs[2] > max_val) begin
                max_val = captured_outputs[2];
                max_idx = 2'd3;  // 11: triangle
            end
            
            // If the maximum value is below threshold, classify as unknown
            if (max_val < 16'sd16384)  // Threshold at 0.5 in fixed point (16384 = 0.5 in Q1.15)
                shape_type <= 2'b00;   // Unknown
            else
                shape_type <= max_idx;
                
            result_valid <= 1'b1;
            
            // Debug: Print the output values and detected shape
            $display("Time %0t: Output values - Circle: %d, Square: %d, Triangle: %d", 
                     $time, captured_outputs[0], captured_outputs[1], captured_outputs[2]);
            $display("Time %0t: Maximum value: %d, Detected shape: %d", 
                     $time, max_val, max_idx);
        end else if (current_state == IDLE) begin
            result_valid <= 1'b0;
        end
    end

endmodule 