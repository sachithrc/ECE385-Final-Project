
module shape_detector_system (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_test,     // Button to start testing
    input  logic [1:0]  image_select,   // 00: circle, 01: square, 10: triangle, 11: custom
    output logic [1:0]  shape_type,     // 00: unknown, 01: circle, 10: square, 11: triangle
    output logic        result_valid    // Indicates valid result
);

    // Internal signals
    logic [7:0]  pixel_data;
    logic        pixel_valid;
    logic        frame_start;
    logic        frame_done;
    
    // Test control state machine
    typedef enum logic [2:0] {
        TEST_IDLE,
        TEST_RUNNING,
        TEST_WAIT_RESULT,
        TEST_COMPLETE
    } test_state_t;
    
    test_state_t test_state, next_test_state;
    
    // Test image provider instance
    test_image_provider image_provider (
        .clk(clk),
        .rst_n(rst_n),
        .start(test_state == TEST_RUNNING),
        .image_select(image_select),
        .pixel_data(pixel_data),
        .pixel_valid(pixel_valid),
        .frame_start(frame_start),
        .frame_done(frame_done)
    );
    
    // Shape detector instance
    shape_detector_top shape_detector (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_data(pixel_data),
        .pixel_valid(pixel_valid),
        .frame_start(frame_start),
        .shape_type(shape_type),
        .result_valid(result_valid)
    );
    
    // Test state machine logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= TEST_IDLE;
        end else begin
            test_state <= next_test_state;
        end
    end
    
    // Test state machine next state logic
    always_comb begin
        next_test_state = test_state;
        
        case (test_state)
            TEST_IDLE: begin
                if (start_test)
                    next_test_state = TEST_RUNNING;
            end
            
            TEST_RUNNING: begin
                if (frame_done)
                    next_test_state = TEST_WAIT_RESULT;
            end
            
            TEST_WAIT_RESULT: begin
                if (result_valid)
                    next_test_state = TEST_COMPLETE;
            end
            
            TEST_COMPLETE: begin
                if (!start_test)  // Wait for button release
                    next_test_state = TEST_IDLE;
            end
            
            default: next_test_state = TEST_IDLE;
        endcase
    end

endmodule 