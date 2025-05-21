`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/24/2025 06:29:36 PM
// Design Name:
// Module Name: shape_generator
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module shape_generator #(
  parameter CX = 320, CY = 240,
            R  = 100,
            S  = 80
)(
  input  logic        clk,
  input  logic        reset,
  input  logic [1:0]  shape_select,
  input  logic [9:0]  drawX,
  input  logic [9:0]  drawY,
  input  logic        vde,
  output logic        shape_edge
);
  // Compute absolute offsets
  logic [10:0] dx_abs, dy_abs;
  always_comb begin
    if (drawX >= CX) dx_abs = drawX - CX; else dx_abs = CX - drawX;
    if (drawY >= CY) dy_abs = drawY - CY; else dy_abs = CY - drawY;
  end

  // Squared distance for circle
  logic [21:0] dist2 = dx_abs*dx_abs + dy_abs*dy_abs;
  localparam int R2 = R*R;
  localparam int Rm12 = (R-1)*(R-1);

  // Border tests
  logic circle_edge = (dist2 <= R2) && (dist2 >= Rm12);
  logic square_edge = ((dx_abs == S) && (dy_abs <= S)) ||
                      ((dy_abs == S) && (dx_abs <= S));

  // Triangle edge:
  //   - two sloping sides when |dx|*R == (|dy|-R)*S  (for ?R?dy?R)
  //   - bottom base at dy == -R
  logic [21:0] lhs = dx_abs * R;
  logic [21:0] rhs = ((CY > drawY ? CY - drawY : drawY - CY) + R) * S;
  logic triangle_edge;
  always_comb begin
    triangle_edge = (drawY == CY + R) && (dx_abs <= S);
   
    if (!triangle_edge && drawY <= CY + R && drawY >= CY - R) begin
        logic [10:0] x_left, x_right;
        logic signed [11:0] y_offset;
       
        y_offset = CY + R - drawY;
       
        x_left = CX - S + ((y_offset * S) / (2 * R));
        x_right = CX + S - ((y_offset * S) / (2 * R));
       
        triangle_edge = (drawX == x_left) || (drawX == x_right);
    end
  end

  always_ff @(posedge clk) begin
    if (reset || !vde)
      shape_edge <= 1'b0;
    else begin
      case (shape_select)
        2'd0: shape_edge <= 1'b0;         // Unknown - no shape
        2'd1: shape_edge <= circle_edge;   // Circle
        2'd2: shape_edge <= square_edge;   // Square
        2'd3: shape_edge <= triangle_edge; // Triangle
      endcase
    end
  end
endmodule 