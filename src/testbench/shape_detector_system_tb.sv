module shape_detector_system_tb;

    // Test bench signals
    logic        clk;
    logic        rst_n;
    logic        start_detection;
    logic [1:0]  image_select;
    logic [1:0]  shape_result;
    logic        result_ready;
    logic        system_busy;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end
    
    // Device under test
    shape_detector_system dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_detection(start_detection),
        .image_select(image_select),
        .shape_result(shape_result),
        .result_ready(result_ready),
        .system_busy(system_busy)
    );
    
    // Helper task for testing each shape
    task test_shape(input [1:0] shape);
        $display("Testing shape: %d", shape);
        image_select = shape;
        start_detection = 1;
        @(posedge clk);
        start_detection = 0;
        
        // Wait for result
        while (!result_ready) @(posedge clk);
        
        // Display result
        case (shape_result)
            2'b00: $display("Result: Unknown shape");
            2'b01: $display("Result: Circle detected");
            2'b10: $display("Result: Square detected");
            2'b11: $display("Result: Triangle detected");
        endcase
        
        // Wait a bit between tests
        repeat (10) @(posedge clk);
    endtask
    
    // Test procedure
    initial begin
        // Initialize signals
        rst_n = 0;
        start_detection = 0;
        image_select = 2'b00;
        
        // Apply reset
        #20;
        rst_n = 1;
        #20;
        
        // Test circle image
        test_shape(2'b00);
        
        // Test square image
        test_shape(2'b01);
        
        // Test triangle image
        test_shape(2'b10);
        
        // Test custom image
        test_shape(2'b11);
        
        // End simulation
        #100;
        $display("All tests completed");
        $finish;
    end
    
    // Monitor for system busy and ready signals
    initial begin
        forever begin
            @(posedge clk);
            if (start_detection)
                $display("Time %0t: Starting detection with image %0d", $time, image_select);
            if (system_busy && !$past(system_busy))
                $display("Time %0t: System busy", $time);
            if (result_ready && !$past(result_ready))
                $display("Time %0t: Result ready: %0d", $time, shape_result);
        end
    end

endmodule 