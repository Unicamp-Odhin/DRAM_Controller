module top (
    input  logic        sys_clk,
    input  logic        rst_n,

    input  logic        rxd,
    output logic        txd,

    output logic [7:0]  led,

    // DRAM interface
    inout  logic [31:0] ddr3_dq,
    inout  logic [3:0]  ddr3_dqs_n,
    inout  logic [3:0]  ddr3_dqs_p,
    output logic [14:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_ras_n,
    output logic        ddr3_cas_n,
    output logic        ddr3_we_n,
    output logic        ddr3_reset_n,
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_ck_n,
    output logic [0:0]  ddr3_cke,
    output logic [0:0]  ddr3_cs_n,
    output logic [3:0]  ddr3_dm,
    output logic [0:0]  ddr3_odt
);
    logic [31:0] counter;

    localparam SYS_CLK_FREQ  = 50_000_000; // 50 MHz
    localparam USER_CLK_FREQ = 100_000_000; // 100 MHz
    localparam REF_CLK_FREQ  = 200_000_000; // 200 MHz
    localparam DRAM_CLK_FREQ = 800_000_000; // 800 MHz
    localparam WORD_SIZE     = 256;

    logic ddr3_clk, ddr3_ref_clk, user_clk;

    clk_wiz_0 clk_wiz_0_inst (
        .clk_out1 (ddr3_clk),     // DDR3 clock - 800 MHz
        .clk_out2 (ddr3_ref_clk), // DDR3 reference clock - 200 MHz
        .clk_out3 (user_clk),     // User clock - 100 MHz
        .resetn   (rst_n),        // Active low reset
        .locked   (),             // Locked signal
        .clk_in1  (sys_clk)       // System clock - 50 MHz
    );

    always_ff @(posedge user_clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 32'b0;
            led     <= 8'b0;
        end else begin
            if(counter >= USER_CLK_FREQ) begin
                counter <= 32'b0;
                led     <= led + 1;
            end else begin
                counter <= counter + 1;
            end
        end
    end

    DRAM_Controller #(
        .USER_CLK_FREQ  (USER_CLK_FREQ),
        .REF_CLK_FREQ   (REF_CLK_FREQ),
        .DRAM_CLK_FREQ  (DRAM_CLK_FREQ),
        .WORD_SIZE      (WORD_SIZE)
    ) u_dram_controller (
        // System clk interface
        .user_clk_i     (user_clk),    // 100 MHz clock
        .rst_n_i        (rst_n),       // Reset (active low)

        // Wishbone Interface
        .cyc_i          (),
        .stb_i          (),
        .we_i           (),
        .addr_i         (),
        .data_i         (),
        .data_o         (),
        .ack_o          (),

        // DRAM clk interface
        .ddr3_clk_i     (ddr3_clk),     // DDR3 clock
        .ddr3_ref_clk_i (ddr3_ref_clk), // DDR3 reference clock

        // DRAM interface
        .ddr3_dq        (ddr3_dq),
        .ddr3_dqs_n     (ddr3_dqs_n),
        .ddr3_dqs_p     (ddr3_dqs_p),
        .ddr3_addr      (ddr3_addr),
        .ddr3_ba        (ddr3_ba),
        .ddr3_ras_n     (ddr3_ras_n),
        .ddr3_cas_n     (ddr3_cas_n),
        .ddr3_we_n      (ddr3_we_n),
        .ddr3_reset_n   (ddr3_reset_n),
        .ddr3_ck_p      (ddr3_ck_p),
        .ddr3_ck_n      (ddr3_ck_n),
        .ddr3_cke       (ddr3_cke),
        .ddr3_cs_n      (ddr3_cs_n),
        .ddr3_dm        (ddr3_dm),
        .ddr3_odt       (ddr3_odt)
    );

endmodule
