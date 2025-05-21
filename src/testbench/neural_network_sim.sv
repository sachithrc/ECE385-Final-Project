// Simulation version of neural_network.sv
// This is a copy of your neural_network.sv with changes for simulation

module neural_network (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  image_data [0:3599], // 60x60 image (3600 pixels)
    output logic        done,
    output logic        active,
    output logic signed [15:0] output_values [0:2] // 3 output classes (circle, square, triangle)
);

    // For debugging purposes
    logic [1:0] simulation_image_type;
    
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
    
    // Layer activations (Q1.15 format)
    logic signed [15:0] input_activations [0:INPUT_SIZE-1];
    logic signed [15:0] h1_activations [0:H1_SIZE-1];
    logic signed [15:0] h2_activations [0:H2_SIZE-1];
    logic signed [15:0] h3_activations [0:H3_SIZE-1];
    
    // Accumulator for current neuron computation
    logic signed [31:0] accumulator; // Wider to avoid overflow
    
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
            simulation_image_type <= 2'b00; // Initialize for debugging
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
                    $display("Time %0t: Neural network done signal asserted", $time);
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
            input_activations[input_counter] <= $signed({1'b0, image_data[input_counter]}) * $signed(16'd128);
        end
    end
    
    // Layer 1: Implement max pooling of 8x8 regions to get 64 features
    always_ff @(posedge clk) begin
        if (current_state == LAYER1) begin
            // Calculate pixel index based on pool_x and pool_y
            logic [11:0] pixel_idx = pool_y * IMAGE_WIDTH + pool_x;
            
            // Boundary check to handle edge cases
            if (pool_x < IMAGE_WIDTH && pool_y < IMAGE_HEIGHT) begin
                // Initialize pool_max at start of new region
                if (region_x == 0 && region_y == 0) begin
                    pool_max <= input_activations[pixel_idx];
                    $display("Time %0t: Starting pooling for region %0d at (%0d,%0d)", 
                             $time, pool_idx, pool_x, pool_y);
                end
                
                // Compare current pixel with max value
                else if (input_activations[pixel_idx] > pool_max) begin
                    pool_max <= input_activations[pixel_idx];
                end
                
                // At the end of a pooling region, store the max value
                if (region_x == POOL_WIDTH-1 && region_y == POOL_HEIGHT-1) begin
                    h1_activations[pool_idx] <= pool_max;
                    $display("Time %0t: Pooling region %0d complete, max value = %d", 
                             $time, pool_idx, pool_max);
                end
            end
        end
    end
    
    // Apply tanh activation to layer 1
    always_ff @(posedge clk) begin
        if (current_state == ACTIVATION1) begin
            // Approximation of tanh using piece-wise linear function
            if (h1_activations[h1_counter] > $signed(16'h4000)) begin // > 1.0
                h1_activations[h1_counter] <= $signed(16'h7FFF); // ~= 1.0
            end else if (h1_activations[h1_counter] < $signed(-16'h4000)) begin // < -1.0
                h1_activations[h1_counter] <= $signed(-16'h7FFF); // ~= -1.0
            end else begin
                // Linear approximation: tanh(x) ~= x for small x
                // For better accuracy, we could implement a lookup table
                h1_activations[h1_counter] <= h1_activations[h1_counter];
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
                accumulator <= $signed(32'd0);
            end else if (h1_counter == 1) begin
                // Add bias to accumulator
                accumulator <= $signed({bias_layer2_data, 16'd0});
                bias_layer2_rd_en <= 1'b0;
            end else begin
                // Accumulate weight * activation
                weights_layer2_rd_en <= 1'b1;
                weights_layer2_addr <= h2_counter * H1_SIZE + (h1_counter - 2);
                
                // Perform MAC operation
                accumulator <= accumulator + 
                               $signed(weights_layer2_data) * $signed(h1_activations[h1_counter - 2]);
            end
            
            // When done with a neuron, save the accumulated value
            if (h1_counter == H1_SIZE-1) begin
                // Truncate accumulator to Q1.15 format
                h2_activations[h2_counter] <= accumulator[31:16];
            end
        end
    end
    
    // Apply tanh activation to layer 2
    always_ff @(posedge clk) begin
        if (current_state == ACTIVATION2) begin
            // Approximation of tanh using piece-wise linear function
            if (h2_activations[h2_counter] > $signed(16'h4000)) begin // > 1.0
                h2_activations[h2_counter] <= $signed(16'h7FFF); // ~= 1.0
            end else if (h2_activations[h2_counter] < $signed(-16'h4000)) begin // < -1.0
                h2_activations[h2_counter] <= $signed(-16'h7FFF); // ~= -1.0
            end else begin
                // Linear approximation: tanh(x) ~= x for small x
                h2_activations[h2_counter] <= h2_activations[h2_counter];
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
                accumulator <= $signed(32'd0);
            end else if (h2_counter == 1) begin
                // Add bias to accumulator
                accumulator <= $signed({bias_layer3_data, 16'd0});
                bias_layer3_rd_en <= 1'b0;
            end else begin
                // Accumulate weight * activation
                weights_layer3_rd_en <= 1'b1;
                weights_layer3_addr <= h3_counter * H2_SIZE + (h2_counter - 2);
                
                // Perform MAC operation
                accumulator <= accumulator + 
                               $signed(weights_layer3_data) * $signed(h2_activations[h2_counter - 2]);
            end
            
            // When done with a neuron, save the accumulated value
            if (h2_counter == H2_SIZE-1) begin
                // Truncate accumulator to Q1.15 format
                h3_activations[h3_counter] <= accumulator[31:16];
            end
        end
    end
    
    // Apply ReLU activation to layer 3
    always_ff @(posedge clk) begin
        if (current_state == ACTIVATION3) begin
            // ReLU: max(0, x)
            if (h3_activations[h3_counter] < $signed(16'd0)) begin
                h3_activations[h3_counter] <= $signed(16'd0);
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
                accumulator <= $signed(32'd0);
            end else if (h3_counter == 1) begin
                // Add bias to accumulator
                accumulator <= $signed({bias_output_data, 16'd0});
                bias_output_rd_en <= 1'b0;
            end else begin
                // Accumulate weight * activation
                weights_output_rd_en <= 1'b1;
                weights_output_addr <= out_counter * H3_SIZE + (h3_counter - 2);
                
                // Perform MAC operation
                accumulator <= accumulator + 
                               $signed(weights_output_data) * $signed(h3_activations[h3_counter - 2]);
            end
            
            // When done with an output neuron, save the accumulated value
            if (h3_counter == H3_SIZE-1) begin
                // Truncate accumulator to Q1.15 format
                output_values[out_counter] <= accumulator[31:16];
                
                // Debug: Print output values when they're calculated
                if (out_counter == OUT_SIZE-1) begin
                    $display("Time %0t: Neural network output values calculated", $time);
                    $display("Time %0t: Output[0]=%d, Output[1]=%d, Output[2]=%d", 
                             $time, output_values[0], output_values[1], output_values[2]);
                end
            end
        end
    end
    
    // For simulation only - UNCOMMENTED FOR SIMULATION
    // We don't need this manual initialization when using BRAM
    /*
    initial begin
        // Use small values for hidden layer weights
        weights_layer2_data = 16'sd100;
        weights_layer3_data = 16'sd100;
        
        // Zero biases for hidden layers
        bias_layer2_data = 16'sd0;
        bias_layer3_data = 16'sd0;
        
        $display("Time %0t: Neural network weights and biases initialized for simulation", $time);
    end
    */
    
    // DEBUGGING TOOLS - These do not affect functionality, only add debug info
    
    // Detect which image is being processed based on the input pattern (debugging only)
    always_ff @(posedge clk) begin
        if (current_state == PREPROCESS && h1_counter == 0) begin
            // Try to detect which image we're processing
            // Check unique patterns in the input data to identify the image type
            // For simplicity, we'll use the pattern of non-zero pixels
            
            logic [7:0] sum_region1 = 0;
            logic [7:0] sum_region2 = 0;
            logic [7:0] sum_region3 = 0;
            
            // Sample characteristic regions to identify the shape
            for (int i = 0; i < 5; i++) begin
                sum_region1 = sum_region1 + image_data[i*IMAGE_WIDTH + i]; // diagonal
                sum_region2 = sum_region2 + image_data[30*IMAGE_WIDTH + 10 + i]; // horizontal middle
                sum_region3 = sum_region3 + image_data[10 + i*IMAGE_WIDTH + 30]; // vertical middle
            end
            
            $display("Time %0t: Image pattern analysis: R1=%0d, R2=%0d, R3=%0d", 
                     $time, sum_region1, sum_region2, sum_region3);
            
            if (sum_region1 > 100 && sum_region2 > 100 && sum_region3 > 100)
                simulation_image_type = 2'b01; // Circle
            else if (sum_region2 > 100 && sum_region3 > 100)
                simulation_image_type = 2'b10; // Square
            else
                simulation_image_type = 2'b11; // Triangle
                
            $display("Time %0t: Detected image type for simulation debugging: %0d", $time, simulation_image_type);
        end
    end

    // Add debug info for the output stage
    always_ff @(posedge clk) begin
        if (current_state == DONE_STATE) begin
            // Add detailed debug information
            $display("Time %0t: FINAL PREDICTION DEBUG - Detected Image: %0d, Outputs: Circle=%0d, Square=%0d, Triangle=%0d", 
                     $time, simulation_image_type, output_values[0], output_values[1], output_values[2]);
                     
            // Identify the maximum output
            logic signed [15:0] max_val = output_values[0];
            logic [1:0] max_idx = 2'b00;
            
            if (output_values[1] > max_val) begin
                max_val = output_values[1];
                max_idx = 2'b01;
            end
            
            if (output_values[2] > max_val) begin
                max_val = output_values[2];
                max_idx = 2'b10;
            end
            
            $display("Time %0t: Maximum output: %0d at index %0d", $time, max_val, max_idx);
        end
    end
    
    // BRAM instances for weights and biases - NO LONGER COMMENTED OUT FOR SIMULATION
    
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
    
endmodule 