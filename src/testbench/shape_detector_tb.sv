// Note: For simulation, use neural_network_sim.sv instead of neural_network.sv
// The neural_network_sim.sv file has the BRAM instantiations commented out
// and the simulation initialization block uncommented.

`timescale 1ns / 1ps

module shape_detector_tb;

    // Parameters
    localparam CLK_PERIOD = 10;  // 100 MHz clock (10ns period)
    localparam TEST_TIMEOUT = 500000; // Timeout value for simulation (in clock cycles)
    
    // Test bench signals
    logic        clk;
    logic        rst_n;
    logic        start_test;
    logic [1:0]  image_select;
    logic [1:0]  shape_type;
    logic        result_valid;
    
    // Simulation control
    integer      sim_cycle_count;
    logic        sim_timeout;
    
    // Instantiate the DUT (Device Under Test)
    shape_detector_system dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_test(start_test),
        .image_select(image_select),
        .shape_type(shape_type),
        .result_valid(result_valid)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Simulation timeout counter
    always @(posedge clk) begin
        if (!rst_n) begin
            sim_cycle_count <= 0;
            sim_timeout <= 0;
        end else begin
            sim_cycle_count <= sim_cycle_count + 1;
            if (sim_cycle_count >= TEST_TIMEOUT) begin
                sim_timeout <= 1;
                $display("Simulation timeout reached at %t", $time);
                $stop;
            end
        end
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        start_test = 0;
        image_select = 2'b00;  // Start with circle
        sim_cycle_count = 0;
        
        // Apply reset
        #(CLK_PERIOD*10);
        rst_n = 1;
        #(CLK_PERIOD*10);
        
        // Test all three shapes
        test_shape(2'b00, "Circle");   // Test circle
        #(CLK_PERIOD*3000);            // Wait between tests
        
        test_shape(2'b01, "Square");   // Test square
        #(CLK_PERIOD*3000);            // Wait between tests
        
        test_shape(2'b10, "Triangle"); // Test triangle
        #(CLK_PERIOD*3000);            // Wait between tests
        
        // End simulation
        $display("All tests completed");
        $finish;
    end
    
    // Task to test a single shape
    task test_shape(input [1:0] shape, input string shape_name);
        $display("Time %0t: Testing %s image...", $time, shape_name);
        
        // Select the image
        image_select = shape;
        #(CLK_PERIOD*50);
        
        // Start the test
        $display("Time %0t: Loading test image for: %s", $time, shape_name);
        start_test = 1;
        #(CLK_PERIOD*50);
        
        // Assert frame_start (happens internally in the module)
        $display("Time %0t: Asserting frame_start", $time);
        
        // Wait for result_valid
        wait(result_valid);
        
        // Check result
        case(shape_type)
            2'b00: $display("Time %0t: Result: Unknown shape detected", $time);
            2'b01: $display("Time %0t: Result: Circle detected", $time);
            2'b10: $display("Time %0t: Result: Square detected", $time);
            2'b11: $display("Time %0t: Result: Triangle detected", $time);
        endcase
        
        // Release start button
        start_test = 0;
        $display("Time %0t: Test complete, waiting before next test", $time);
        
        // Wait for system to return to idle
        wait(!result_valid);
    endtask

endmodule 