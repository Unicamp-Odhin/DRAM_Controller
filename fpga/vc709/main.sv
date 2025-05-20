`timescale 1ns / 1ps

module top(
    input  logic clk_ref_p,
    input  logic clk_ref_n,
    input  logic sys_rst_i,

    input  logic button_center,

    input  logic RxD,
    output logic TxD,
    
    output logic [7:0] led,
    inout  logic [7:0] gpio_switch
);
    
logic clk_o;
logic clk_ref; // Sinal de clock single-ended

// Instância do buffer diferencial
IBUFDS #(
    .DIFF_TERM    ("TRUE"),  // Habilita ou desabilita o terminador diferencial
    .IBUF_LOW_PWR ("FALSE"), // Ativa o modo de baixa potência
    .IOSTANDARD   ("DIFF_SSTL15")
) ibufds_inst (
    .O  (clk_ref),    // Clock single-ended de saída
    .I  (clk_ref_p),  // Entrada diferencial positiva
    .IB (clk_ref_n)   // Entrada diferencial negativa
);

clk_wiz_0 clk_wiz_inst (
    .clk_in1  (clk_ref),
    .resetn   (!sys_rst_i),
    .clk_out1 (clk_o),
    .locked   ()
);



endmodule
