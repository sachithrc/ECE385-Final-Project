module neural_network (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  image_data [0:3599], // 60x60 image (3600 pixels)
    output logic        done,
    output logic        active,
    output logic signed [15:0] output_values [0:2] // 3 output classes (circle, square, triangle)
);

    // Fixed point format: Q1.15 (1 sign bit, 15 fractional bits)
    // Range: [-1, 1-2^-15] ~= [-1, 0.99997]
    // Resolution: 2^-15 ~= 0.00003
    
    // Parameters
    localparam INPUT_SIZE = 3600; // 60x60 image
    localparam H1_SIZE = 64;     // First hidden layer (reduced from 256)
    localparam H2_SIZE = 64;     // Second hidden layer (reduced from 256)
    localparam H3_SIZE = 64;     // Third hidden layer (reduced from 256)
    localparam OUT_SIZE = 3;      // Output layer (circle, square, triangle)
    
    // Parameters for pooling
    localparam POOL_SIZE = 8;    // 8x8 pooling regions (60/8 = 7.5, we'll handle edge cases)
    localparam POOL_WIDTH = 8;   // Width of each pooling region
    localparam POOL_HEIGHT = 8;  // Height of each pooling region
    localparam IMAGE_WIDTH = 60; // Width of input image
    localparam IMAGE_HEIGHT = 60;// Height of input image
    
    // State definition
    typedef enum logic [3:0] {
        IDLE,
        PREPROCESS,
        LAYER1,
        ACTIVATION1,
        LAYER2,
        ACTIVATION2,
        LAYER3,
        ACTIVATION3,
        OUTPUT_LAYER,
        DONE_STATE
    } state_t;
    
    state_t current_state, next_state;
    // Debug: Keep track of previous state for transition detection
    state_t prev_state;
    
    // State machine registers
    logic [$clog2(INPUT_SIZE)-1:0] input_counter;
    logic [$clog2(H1_SIZE)-1:0] h1_counter;
    logic [$clog2(H2_SIZE)-1:0] h2_counter;
    logic [$clog2(H3_SIZE)-1:0] h3_counter;
    logic [$clog2(OUT_SIZE)-1:0] out_counter;
    
    // Pooling counters and registers
    logic [5:0] pool_x, pool_y;           // X and Y position within the image (0-59)
    logic [2:0] region_x, region_y;       // X and Y position within the pooling region (0-7)
    logic [15:0] pool_max;                // Maximum value in current pooling region
    logic [11:0] pool_idx;                // Index for pooling (8x8=64 total pooling regions)
    logic pool_done;                      // Flag to indicate pooling is complete
    
    // Flag to indicate completion of a neuron's computation
    logic neuron_complete;
    
    // Layer activations (Q1.15 format) - using BRAMs instead of arrays
    // BRAM for input activations
    logic input_act_wr_en;
    logic [$clog2(INPUT_SIZE)-1:0] input_act_addr;
    logic signed [15:0] input_act_data_in;
    logic signed [15:0] input_act_data_out;
    
    // BRAM for h1 activations
    logic h1_act_wr_en;
    logic [$clog2(H1_SIZE)-1:0] h1_act_addr;
    logic signed [15:0] h1_act_data_in;
    logic signed [15:0] h1_act_data_out;
    
    // BRAM for h2 activations
    logic h2_act_wr_en;
    logic [$clog2(H2_SIZE)-1:0] h2_act_addr;
    logic signed [15:0] h2_act_data_in;
    logic signed [15:0] h2_act_data_out;
    
    // BRAM for h3 activations
    logic h3_act_wr_en;
    logic [$clog2(H3_SIZE)-1:0] h3_act_addr;
    logic signed [15:0] h3_act_data_in;
    logic signed [15:0] h3_act_data_out;
    
    // Accumulator for each layer computation (to avoid multiple drivers)
    logic signed [31:0] layer2_accumulator; // Accumulator for layer 2
    logic signed [31:0] layer3_accumulator; // Accumulator for layer 3
    logic signed [31:0] output_accumulator; // Accumulator for output layer
    
    // Weights and biases (loaded from BRAMs)
    // We're declaring interfaces for them
    // Layer 1 is bypassed, so we don't need those signals anymore
    
    logic weights_layer2_rd_en;
    logic [$clog2(H1_SIZE*H2_SIZE)-1:0] weights_layer2_addr;
    logic signed [15:0] weights_layer2_data;
    
    logic weights_layer3_rd_en;
    logic [$clog2(H2_SIZE*H3_SIZE)-1:0] weights_layer3_addr;
    logic signed [15:0] weights_layer3_data;
    
    logic weights_output_rd_en;
    logic [$clog2(H3_SIZE*OUT_SIZE)-1:0] weights_output_addr;
    logic signed [15:0] weights_output_data;
    
    logic bias_layer2_rd_en;
    logic [$clog2(H2_SIZE)-1:0] bias_layer2_addr;
    logic signed [15:0] bias_layer2_data;
    
    logic bias_layer3_rd_en;
    logic [$clog2(H3_SIZE)-1:0] bias_layer3_addr;
    logic signed [15:0] bias_layer3_data;
    
    logic bias_output_rd_en;
    logic [$clog2(OUT_SIZE)-1:0] bias_output_addr;
    logic signed [15:0] bias_output_data;
    
    // Debug: Function to convert state to string for debugging
    function string state_to_string(state_t state);
        case (state)
            IDLE: return "IDLE";
            PREPROCESS: return "PREPROCESS";
            LAYER1: return "LAYER1";
            ACTIVATION1: return "ACTIVATION1";
            LAYER2: return "LAYER2";
            ACTIVATION2: return "ACTIVATION2";
            LAYER3: return "LAYER3";
            ACTIVATION3: return "ACTIVATION3";
            OUTPUT_LAYER: return "OUTPUT_LAYER";
            DONE_STATE: return "DONE_STATE";
            default: return "UNKNOWN";
        endcase
    endfunction
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            prev_state <= IDLE;
        end else begin
            // Debug: Track state transitions
            prev_state <= current_state;
            if (prev_state != next_state) begin
                $display("Time %0t: Neural network state transition: %s -> %s", 
                         $time, state_to_string(current_state), state_to_string(next_state));
            end
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PREPROCESS;
                    $display("Time %0t: Neural network received start signal", $time);
                end
            end
            
            PREPROCESS: begin
                if (input_counter == INPUT_SIZE-1) begin
                    next_state = LAYER1;
                    $display("Time %0t: Preprocessing complete, moving to LAYER1", $time);
                end
            end
            
            LAYER1: begin
                // Changed condition for pooling: when all pooling regions are processed
                if (pool_done) begin
                    next_state = ACTIVATION1;
                    $display("Time %0t: LAYER1 pooling complete, moving to ACTIVATION1", $time);
                end
            end
            
            ACTIVATION1: begin
                if (h1_counter == H1_SIZE-1) begin
                    next_state = LAYER2;
                    $display("Time %0t: ACTIVATION1 complete, moving to LAYER2", $time);
                end
            end
            
            LAYER2: begin
                if (h2_counter == H2_SIZE-1 && h1_counter == H1_SIZE-1) begin
                    next_state = ACTIVATION2;
                    $display("Time %0t: LAYER2 computation complete, moving to ACTIVATION2", $time);
                end
            end
            
            ACTIVATION2: begin
                if (h2_counter == H2_SIZE-1) begin
                    next_state = LAYER3;
                    $display("Time %0t: ACTIVATION2 complete, moving to LAYER3", $time);
                end
            end
            
            LAYER3: begin
                if (h3_counter == H3_SIZE-1 && h2_counter == H2_SIZE-1) begin
                    next_state = ACTIVATION3;
                    $display("Time %0t: LAYER3 computation complete, moving to ACTIVATION3", $time);
                end
            end
            
            ACTIVATION3: begin
                if (h3_counter == H3_SIZE-1) begin
                    next_state = OUTPUT_LAYER;
                    $display("Time %0t: ACTIVATION3 complete, moving to OUTPUT_LAYER", $time);
                end
            end
            
            OUTPUT_LAYER: begin
                if (out_counter == OUT_SIZE-1 && h3_counter == H3_SIZE-1) begin
                    next_state = DONE_STATE;
                    $display("Time %0t: OUTPUT_LAYER computation complete, moving to DONE_STATE", $time);
                end
            end
            
            DONE_STATE: begin
                $display("Time %0t: Neural network processing complete", $time);
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Control signals based on state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            done <= 1'b0;
            neuron_complete <= 1'b0;
            pool_done <= 1'b0;
            
            // Initialize output values to prevent X propagation
            output_values[0] <= 16'sd0;
            output_values[1] <= 16'sd0;
            output_values[2] <= 16'sd0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        active <= 1'b1;
                        $display("Time %0t: Neural network activated", $time);
                    end
                    done <= 1'b0;
                    neuron_complete <= 1'b0;
                    pool_done <= 1'b0;
                    
                    // Preserve output values - do not reset them when entering IDLE
                    // This maintains their values for the parent module to read
                    output_values[0] <= output_values[0];
                    output_values[1] <= output_values[1];
                    output_values[2] <= output_values[2];
                end
                
                LAYER1: begin
                    // Set pool_done flag when all pooling regions are processed
                    if (pool_idx == H1_SIZE-1) begin
                        pool_done <= 1'b1;
                        $display("Time %0t: Pooling completed for all regions", $time);
                    end
                end
                
                DONE_STATE: begin
                    active <= 1'b0;
                    done <= 1'b1;
                    neuron_complete <= 1'b0;
                    pool_done <= 1'b0;
                    
                    // Add explicit latching logic to hold the output values
                    // This ensures they're maintained after computation is finished
                    output_values[0] <= output_values[0];
                    output_values[1] <= output_values[1];
                    output_values[2] <= output_values[2];
                    
                    $display("Time %0t: Neural network done signal asserted", $time);
                    // Reprint output values to confirm they're still valid
                    $display("Time %0t: Final outputs - Circle: %d, Square: %d, Triangle: %d", 
                             $time, output_values[0], output_values[1], output_values[2]);
                end
                
                default: begin
                    active <= active;
                    done <= 1'b0;
                    neuron_complete <= 1'b0;
                end
            endcase
        end
    end
    
    // Counters for each layer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_counter <= '0;
            h1_counter <= '0;
            h2_counter <= '0;
            h3_counter <= '0;
            out_counter <= '0;
            pool_x <= '0;
            pool_y <= '0;
            region_x <= '0;
            region_y <= '0;
            pool_idx <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    input_counter <= '0;
                    h1_counter <= '0;
                    h2_counter <= '0;
                    h3_counter <= '0;
                    out_counter <= '0;
                    pool_x <= '0;
                    pool_y <= '0;
                    region_x <= '0;
                    region_y <= '0;
                    pool_idx <= '0;
                end
                
                PREPROCESS: begin
                    if (input_counter < INPUT_SIZE-1)
                        input_counter <= input_counter + 1'b1;
                    else
                        input_counter <= '0;
                end
                
                LAYER1: begin
                    // Max pooling logic
                    if (region_x < POOL_WIDTH-1) begin
                        region_x <= region_x + 1'b1;
                        pool_x <= pool_x + 1'b1;
                    end else begin
                        region_x <= '0;
                        pool_x <= pool_idx[5:0] * POOL_WIDTH; // Reset X to start of region
                        
                        if (region_y < POOL_HEIGHT-1) begin
                            region_y <= region_y + 1'b1;
                            pool_y <= pool_y + 1'b1;
                        end else begin
                            region_y <= '0;
                            pool_y <= (pool_idx[11:6]) * POOL_HEIGHT; // Reset Y to start of region
                            
                            if (pool_idx < H1_SIZE-1) begin
                                pool_idx <= pool_idx + 1'b1;
                                $display("Time %0t: Moving to next pooling region %0d", $time, pool_idx + 1);
                            end
                        end
                    end
                end
                
                ACTIVATION1: begin
                    if (h1_counter < H1_SIZE-1)
                        h1_counter <= h1_counter + 1'b1;
                    else
                        h1_counter <= '0;
                end
                
                LAYER2: begin
                    if (h1_counter < H1_SIZE-1)
                        h1_counter <= h1_counter + 1'b1;
                    else begin
                        h1_counter <= '0;
                        if (h2_counter < H2_SIZE-1)
                            h2_counter <= h2_counter + 1'b1;
                    end
                end
                
                ACTIVATION2: begin
                    if (h2_counter < H2_SIZE-1)
                        h2_counter <= h2_counter + 1'b1;
                    else
                        h2_counter <= '0;
                end
                
                LAYER3: begin
                    if (h2_counter < H2_SIZE-1)
                        h2_counter <= h2_counter + 1'b1;
                    else begin
                        h2_counter <= '0;
                        if (h3_counter < H3_SIZE-1)
                            h3_counter <= h3_counter + 1'b1;
                    end
                end
                
                ACTIVATION3: begin
                    if (h3_counter < H3_SIZE-1)
                        h3_counter <= h3_counter + 1'b1;
                    else
                        h3_counter <= '0;
                end
                
                OUTPUT_LAYER: begin
                    if (h3_counter < H3_SIZE-1)
                        h3_counter <= h3_counter + 1'b1;
                    else begin
                        h3_counter <= '0;
                        if (out_counter < OUT_SIZE-1)
                            out_counter <= out_counter + 1'b1;
                    end
                end
            endcase
        end
    end
    
    // Preprocess: Convert 8-bit image data to fixed-point Q1.15 format
    always_ff @(posedge clk) begin
        if (current_state == PREPROCESS) begin
            // Normalize to [0, 1] range by dividing by 255, then convert to Q1.15
            // Scale to [-1, 1] by calculating 2*x - 1
            // For simplicity, we're directly calculating the Q1.15 value:
            // (x/255)*2^15 = x * 128
            input_act_wr_en <= 1'b1;
            input_act_addr <= input_counter;
            input_act_data_in <= $signed({1'b0, image_data[input_counter]}) * $signed(16'd128);
        end
    end
    
    // Layer 1: Implement max pooling of 8x8 regions to get 64 features
    always_ff @(posedge clk) begin
        if (current_state == LAYER1) begin
            // Calculate pixel index based on pool_x and pool_y
            logic [11:0] pixel_idx = pool_y * IMAGE_WIDTH + pool_x;
            
            // Set read address for input activations
            input_act_wr_en <= 1'b0;
            input_act_addr <= pixel_idx;
            
            // Boundary check to handle edge cases
            if (pool_x < IMAGE_WIDTH && pool_y < IMAGE_HEIGHT) begin
                // Initialize pool_max at start of new region
                if (region_x == 0 && region_y == 0) begin
                    pool_max <= input_act_data_out;
                    $display("Time %0t: Starting pooling for region %0d at (%0d,%0d)", 
                             $time, pool_idx, pool_x, pool_y);
                end
                
                // Compare current pixel with max value
                else if (input_act_data_out > pool_max) begin
                    pool_max <= input_act_data_out;
                end
                
                // At the end of a pooling region, store the max value
                if (region_x == POOL_WIDTH-1 && region_y == POOL_HEIGHT-1) begin
                    h1_act_wr_en <= 1'b1;
                    h1_act_addr <= pool_idx;
                    h1_act_data_in <= pool_max;
                    $display("Time %0t: Pooling region %0d complete, max value = %d", 
                             $time, pool_idx, pool_max);
                end
            end
        end
    end
    
    // Apply tanh activation to layer 1
    always_ff @(posedge clk) begin
        if (current_state == ACTIVATION1) begin
            // Set read address for h1 activations
            h1_act_wr_en <= 1'b0;
            h1_act_addr <= h1_counter;
            
            // Need to apply activation one cycle after reading
            if (h1_counter > 0) begin
                // Approximation of tanh using piece-wise linear function
                h1_act_wr_en <= 1'b1;
                h1_act_addr <= h1_counter - 1;
                
                if (h1_act_data_out > $signed(16'h4000)) begin // > 1.0
                    h1_act_data_in <= $signed(16'h7FFF); // ~= 1.0
                end else if (h1_act_data_out < $signed(-16'h4000)) begin // < -1.0
                    h1_act_data_in <= $signed(-16'h7FFF); // ~= -1.0
                end else begin
                    // Linear approximation: tanh(x) ~= x for small x
                    // For better accuracy, we could implement a lookup table
                    h1_act_data_in <= h1_act_data_out;
                end
            end
        end
    end
    
    // Compute layer 2 (fully connected with tanh activation)
    always_ff @(posedge clk) begin
        if (current_state == LAYER2) begin
            if (h1_counter == 0) begin
                // Load bias at the start of computation for each neuron
                bias_layer2_rd_en <= 1'b1;
                bias_layer2_addr <= h2_counter;
                layer2_accumulator <= $signed(32'd0);
            end else if (h1_counter == 1) begin
                // Add bias to accumulator
                layer2_accumulator <= $signed({bias_layer2_data, 16'd0});
                bias_layer2_rd_en <= 1'b0;
            end else begin
                // Accumulate weight * activation
                weights_layer2_rd_en <= 1'b1;
                weights_layer2_addr <= h2_counter * H1_SIZE + (h1_counter - 2);
                
                // Set read address for h1 activations
                h1_act_wr_en <= 1'b0;
                h1_act_addr <= h1_counter - 2;
                
                // Perform MAC operation
                layer2_accumulator <= layer2_accumulator + 
                                     $signed(weights_layer2_data) * $signed(h1_act_data_out);
            end
            
            // When done with a neuron, save the accumulated value
            if (h1_counter == H1_SIZE-1) begin
                // Truncate accumulator to Q1.15 format
                h2_act_wr_en <= 1'b1;
                h2_act_addr <= h2_counter;
                h2_act_data_in <= layer2_accumulator[31:16];
            end
        end
    end
    
    // Apply tanh activation to layer 2
    always_ff @(posedge clk) begin
        if (current_state == ACTIVATION2) begin
            // Set read address for h2 activations
            h2_act_wr_en <= 1'b0;
            h2_act_addr <= h2_counter;
            
            // Need to apply activation one cycle after reading
            if (h2_counter > 0) begin
                // Approximation of tanh using piece-wise linear function
                h2_act_wr_en <= 1'b1;
                h2_act_addr <= h2_counter - 1;
                
                if (h2_act_data_out > $signed(16'h4000)) begin // > 1.0
                    h2_act_data_in <= $signed(16'h7FFF); // ~= 1.0
                end else if (h2_act_data_out < $signed(-16'h4000)) begin // < -1.0
                    h2_act_data_in <= $signed(-16'h7FFF); // ~= -1.0
                end else begin
                    // Linear approximation: tanh(x) ~= x for small x
                    h2_act_data_in <= h2_act_data_out;
                end
            end
        end
    end
    
    // Compute layer 3 (fully connected with ReLU activation)
    always_ff @(posedge clk) begin
        if (current_state == LAYER3) begin
            if (h2_counter == 0) begin
                // Load bias at the start of computation for each neuron
                bias_layer3_rd_en <= 1'b1;
                bias_layer3_addr <= h3_counter;
                layer3_accumulator <= $signed(32'd0);
            end else if (h2_counter == 1) begin
                // Add bias to accumulator
                layer3_accumulator <= $signed({bias_layer3_data, 16'd0});
                bias_layer3_rd_en <= 1'b0;
            end else begin
                // Accumulate weight * activation
                weights_layer3_rd_en <= 1'b1;
                weights_layer3_addr <= h3_counter * H2_SIZE + (h2_counter - 2);
                
                // Set read address for h2 activations
                h2_act_wr_en <= 1'b0;
                h2_act_addr <= h2_counter - 2;
                
                // Perform MAC operation
                layer3_accumulator <= layer3_accumulator + 
                                     $signed(weights_layer3_data) * $signed(h2_act_data_out);
            end
            
            // When done with a neuron, save the accumulated value
            if (h2_counter == H2_SIZE-1) begin
                // Truncate accumulator to Q1.15 format
                h3_act_wr_en <= 1'b1;
                h3_act_addr <= h3_counter;
                h3_act_data_in <= layer3_accumulator[31:16];
            end
        end
    end
    
    // Apply ReLU activation to layer 3
    always_ff @(posedge clk) begin
        if (current_state == ACTIVATION3) begin
            // Set read address for h3 activations
            h3_act_wr_en <= 1'b0;
            h3_act_addr <= h3_counter;
            
            // Need to apply activation one cycle after reading
            if (h3_counter > 0) begin
                // ReLU: max(0, x)
                h3_act_wr_en <= 1'b1;
                h3_act_addr <= h3_counter - 1;
                
                if (h3_act_data_out < $signed(16'd0)) begin
                    h3_act_data_in <= $signed(16'd0);
                end else begin
                    h3_act_data_in <= h3_act_data_out;
                end
            end
        end
    end
    
    // Compute output layer (fully connected, no activation - we'll do softmax in top module)
    always_ff @(posedge clk) begin
        if (current_state == OUTPUT_LAYER) begin
            if (h3_counter == 0) begin
                // Load bias at the start of computation for each output neuron
                bias_output_rd_en <= 1'b1;
                bias_output_addr <= out_counter;
                output_accumulator <= $signed(32'd0);
            end else if (h3_counter == 1) begin
                // Add bias to accumulator
                output_accumulator <= $signed({bias_output_data, 16'd0});
                bias_output_rd_en <= 1'b0;
            end else begin
                // Accumulate weight * activation
                weights_output_rd_en <= 1'b1;
                weights_output_addr <= out_counter * H3_SIZE + (h3_counter - 2);
                
                // Set read address for h3 activations
                h3_act_wr_en <= 1'b0;
                h3_act_addr <= h3_counter - 2;
                
                // Perform MAC operation
                output_accumulator <= output_accumulator + 
                                     $signed(weights_output_data) * $signed(h3_act_data_out);
            end
            
            // When done with an output neuron, save the accumulated value
            if (h3_counter == H3_SIZE-1) begin
                // Truncate accumulator to Q1.15 format
                output_values[out_counter] <= output_accumulator[31:16];
                
                // Debug: Print output values when they're calculated
                if (out_counter == OUT_SIZE-1) begin
                    $display("Time %0t: Neural network output values calculated", $time);
                    $display("Time %0t: Output[0]=%d, Output[1]=%d, Output[2]=%d", 
                             $time, output_values[0], output_values[1], output_values[2]);
                end
            end
        end
    end
    
    // BRAM instances for weights and biases
    // Layer 2 Weights BRAM
    layer2_weights layer2_weights_bram (
        .clka(clk),                     // input wire clka
        .ena(weights_layer2_rd_en),     // input wire ena
        .addra(weights_layer2_addr),    // input wire [12 : 0] addra
        .douta(weights_layer2_data)     // output wire [15 : 0] douta
    );
    
    // Layer 2 Biases BRAM
    layer2_bias layer2_biases_bram (
        .clka(clk),                     // input wire clka
        .ena(bias_layer2_rd_en),        // input wire ena
        .addra(bias_layer2_addr),       // input wire [5 : 0] addra
        .douta(bias_layer2_data)        // output wire [15 : 0] douta
    );
    
    // Layer 3 Weights BRAM
    layer3_weights layer3_weights_bram (
        .clka(clk),                     // input wire clka
        .ena(weights_layer3_rd_en),     // input wire ena
        .addra(weights_layer3_addr),    // input wire [12 : 0] addra
        .douta(weights_layer3_data)     // output wire [15 : 0] douta
    );
    
    // Layer 3 Biases BRAM
    layer3_bias layer3_biases_bram (
        .clka(clk),                     // input wire clka
        .ena(bias_layer3_rd_en),        // input wire ena
        .addra(bias_layer3_addr),       // input wire [5 : 0] addra
        .douta(bias_layer3_data)        // output wire [15 : 0] douta
    );
    
    // Layer 4 (Output) Weights BRAM
    layer4_weights output_weights_bram (
        .clka(clk),                     // input wire clka
        .ena(weights_output_rd_en),     // input wire ena
        .addra(weights_output_addr),    // input wire [7 : 0] addra
        .douta(weights_output_data)     // output wire [15 : 0] douta
    );
    
    // Layer 4 (Output) Biases BRAM
    layer4_bias output_biases_bram (
        .clka(clk),                     // input wire clka
        .ena(bias_output_rd_en),        // input wire ena
        .addra(bias_output_addr),       // input wire [1 : 0] addra
        .douta(bias_output_data)        // output wire [15 : 0] douta
    );
    
    // Activation storage BRAMs
    // Simple dual-port BRAM for input activations
    input_activations input_act_bram (
        .clka(clk),                     // Port A: Write port
        .ena(input_act_wr_en),          // Enable for port A
        .wea(input_act_wr_en),          // Write enable for port A
        .addra(input_act_addr),         // Address for port A
        .dina(input_act_data_in),       // Data input for port A
        .clkb(clk),                     // Port B: Read port
        .enb(1'b1),                     // Enable for port B (always enabled)
        .addrb(input_act_addr),         // Address for port B
        .doutb(input_act_data_out)      // Data output for port B
    );
    
    // Simple dual-port BRAM for h1 activations
    h1_activations h1_act_bram (
        .clka(clk),                     // Port A: Write port
        .ena(h1_act_wr_en),             // Enable for port A
        .wea(h1_act_wr_en),             // Write enable for port A
        .addra(h1_act_addr),            // Address for port A
        .dina(h1_act_data_in),          // Data input for port A
        .clkb(clk),                     // Port B: Read port
        .enb(1'b1),                     // Enable for port B (always enabled)
        .addrb(h1_act_addr),            // Address for port B
        .doutb(h1_act_data_out)         // Data output for port B
    );
    
    // Simple dual-port BRAM for h2 activations
    h2_activations h2_act_bram (
        .clka(clk),                     // Port A: Write port
        .ena(h2_act_wr_en),             // Enable for port A
        .wea(h2_act_wr_en),             // Write enable for port A
        .addra(h2_act_addr),            // Address for port A
        .dina(h2_act_data_in),          // Data input for port A
        .clkb(clk),                     // Port B: Read port
        .enb(1'b1),                     // Enable for port B (always enabled)
        .addrb(h2_act_addr),            // Address for port B
        .doutb(h2_act_data_out)         // Data output for port B
    );
    
    // Simple dual-port BRAM for h3 activations
    h3_activations h3_act_bram (
        .clka(clk),                     // Port A: Write port
        .ena(h3_act_wr_en),             // Enable for port A
        .wea(h3_act_wr_en),             // Write enable for port A
        .addra(h3_act_addr),            // Address for port A
        .dina(h3_act_data_in),          // Data input for port A
        .clkb(clk),                     // Port B: Read port
        .enb(1'b1),                     // Enable for port B (always enabled)
        .addrb(h3_act_addr),            // Address for port B
        .doutb(h3_act_data_out)         // Data output for port B
    );
    
    // For simulation only - remove when using actual BRAMs
    // Commenting out the original simulation code since we're now using BRAMs
    /*
    initial begin
        // Use small values for weights and zero for biases to avoid divergence
        weights_layer1_data = 16'sd100;  // 0.003 in Q1.15
        weights_layer2_data = 16'sd100;
        weights_layer3_data = 16'sd100;
        weights_output_data = 16'sd100;
        
        bias_layer1_data = 16'sd0;
        bias_layer2_data = 16'sd0;
        bias_layer3_data = 16'sd0;
        bias_output_data = 16'sd0;
        
        $display("Time %0t: Neural network weights and biases initialized for simulation", $time);
    end
    */
    
endmodule 