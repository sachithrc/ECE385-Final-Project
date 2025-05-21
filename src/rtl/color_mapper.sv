//-------------------------------------------------------------------------
//    Color_Mapper.sv                                                    --
//    Stephen Kempf                                                      --
//    3-1-06                                                             --
//                                                                       --
//    Modified by David Kesler  07-16-2008                               --
//    Translated by Joe Meng    07-07-2013                               --
//    Modified by Zuofu Cheng   08-19-2023                               --
//                                                                       --
//    Fall 2023 Distribution                                             --
//                                                                       --
//    For use with ECE 385 USB + HDMI                                    --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------


module color_mapper (
  input  logic        shape_edge,
  input  logic [9:0]  DrawX,
  input  logic [9:0]  DrawY,
  output logic [3:0]  Red,
  output logic [3:0]  Green,
  output logic [3:0]  Blue
);
  // Background: white
  localparam logic [3:0] BG = 4'hF;
  // Outline color: black
  localparam logic [3:0] SH = 4'h0;

  always_comb begin
    if (shape_edge) begin
      Red   = SH;
      Green = SH;
      Blue  = SH;
    end else begin
      Red   = BG;
      Green = BG;
      Blue  = BG;
    end
  end
endmodule 