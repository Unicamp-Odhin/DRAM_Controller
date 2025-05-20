module top (
    input  logic clk,
    input  logic CPU_RESETN,

    input  logic rx,
    output logic tx,

    output logic [15:0]LED,
    inout  logic [7:0] JA,

    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic VGA_HS,
    output logic VGA_VS
);


endmodule
