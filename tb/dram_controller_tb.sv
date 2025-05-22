`timescale 1ns/1ps

module DRAM_Controller_tb;

    // Parâmetros
    parameter WORD_SIZE = 128;

    // Clocks
    logic user_clk_i = 0;
    logic ddr3_clk_i = 0;
    logic ddr3_ref_clk_i = 0;

    always #5 user_clk_i = ~user_clk_i;       // 100 MHz
    always #2.5 ddr3_clk_i = ~ddr3_clk_i;     // 200 MHz
    always #2.5 ddr3_ref_clk_i = ~ddr3_ref_clk_i;

    // Entradas
    logic rst_n_i = 0;
    logic cyc_i, stb_i, we_i;
    logic [31:0] addr_i;
    logic [WORD_SIZE-1:0] data_i;

    // Saídas
    logic [WORD_SIZE-1:0] data_o;
    logic ack_o;
    logic req_empty, resp_empty;

    // DRAM interface fictício
    logic [31:0] ddr3_dq;
    logic [3:0] ddr3_dqs_n, ddr3_dqs_p;
    logic [14:0] ddr3_addr;
    logic [2:0] ddr3_ba;
    logic ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n;
    logic [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt;
    logic [3:0] ddr3_dm;

    // DUT
    DRAM_Controller #(.WORD_SIZE(WORD_SIZE)) dut (
        .user_clk_i, .rst_n_i,
        .cyc_i, .stb_i, .we_i,
        .addr_i, .data_i, .data_o, .ack_o,
        .ddr3_clk_i, .ddr3_ref_clk_i,
        .ddr3_dq, .ddr3_dqs_n, .ddr3_dqs_p,
        .ddr3_addr, .ddr3_ba, .ddr3_ras_n,
        .ddr3_cas_n, .ddr3_we_n, .ddr3_reset_n,
        .ddr3_ck_p, .ddr3_ck_n, .ddr3_cke,
        .ddr3_cs_n, .ddr3_dm, .ddr3_odt,
        .req_empty, .resp_empty
    );

    // Tarefa auxiliar para escrever
    task wb_write(input [31:0] addr, input [WORD_SIZE-1:0] data);
        begin
            @(posedge user_clk_i);
            addr_i = addr;
            data_i = data;
            we_i   = 1;
            stb_i  = 1;
            cyc_i  = 1;
            @(posedge user_clk_i);
            wait (ack_o);
            @(posedge user_clk_i);
            stb_i = 0;
            cyc_i = 0;
            we_i  = 0;
        end
    endtask

    // Tarefa auxiliar para ler
    task wb_read(input [31:0] addr, output [WORD_SIZE-1:0] data);
        begin
            @(posedge user_clk_i);
            addr_i = addr;
            we_i   = 0;
            stb_i  = 1;
            cyc_i  = 1;
            wait (ack_o);
            data = data_o;
            @(posedge user_clk_i);
            stb_i = 0;
            cyc_i = 0;
        end
    endtask

    initial begin
        $display("Iniciando Testbench...");
        $dumpfile("build/dram_controller_tb.vcd");
        $dumpvars(0, dram_controller_tb);

        rst_n_i = 0;
        addr_i = 0;
        data_i = 0;
        stb_i  = 0;
        cyc_i  = 0;
        we_i   = 0;

        #100;
        rst_n_i = 1;

        #1000;

        // Escrita
        $display("Escrevendo dado na memória...");
        wb_write(32'h00000010, 128'hAABB_CCDD_EEFF_0011_2233_4455_6677_8899);

        #1000;

        // Leitura
        logic [WORD_SIZE-1:0] read_data;
        $display("Lendo dado da memória...");
        wb_read(32'h00000010, read_data);

        $display("Dado lido: %h", read_data);

        #1000;
        $finish;
    end

endmodule
