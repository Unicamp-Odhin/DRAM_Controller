module top #(
    parameter SYS_CLK_FREQ  = 50_000_000, // 50 MHz
    parameter USER_CLK_FREQ = 100_000_000, // 100 MHz
    parameter REF_CLK_FREQ  = 200_000_000, // 200 MHz
    parameter DRAM_CLK_FREQ = 800_000_000, // 800 MHz
    parameter WORD_SIZE     = 128          // Word size for DRAM controller
) (
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
    // Sinais para simular transação Wishbone
    logic        wb_cyc, wb_stb, wb_we;
    logic [31:0] wb_addr;
    logic [WORD_SIZE-1:0] wb_data_i;
    logic [WORD_SIZE-1:0] wb_data_o;
    logic        wb_ack;

    logic ddr3_clk, ddr3_ref_clk, user_clk;

    clk_wiz_0 clk_wiz_0_inst (
        .clk_out1 (ddr3_clk),     // DDR3 clock - 800 MHz
        .clk_out2 (ddr3_ref_clk), // DDR3 reference clock - 200 MHz
        .clk_out3 (user_clk),     // User clock - 100 MHz
        .resetn   (rst_n),        // Active low reset
        .locked   (),             // Locked signal
        .clk_in1  (sys_clk)       // System clock - 50 MHz
    );

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
        .cyc_i          (wb_cyc),
        .stb_i          (wb_stb),
        .we_i           (wb_we),
        .addr_i         (wb_addr),
        .data_i         (wb_data_i),
        .data_o         (wb_data_o),
        .ack_o          (wb_ack),

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

    typedef enum logic [2:0] {
        TST_IDLE,
        TST_WRITE,
        TST_WAIT_WRITE,
        TST_READ,
        TST_WAIT_READ,
        TST_CHECK
    } test_state_t;

    test_state_t test_state = TST_IDLE;
    logic [15:0] delay_counter;
    logic test_pass;

    localparam TEST_VALUE = {WORD_SIZE{1'b10100101}}; // Padrão A5 repetido
    localparam logic [127:0] TEST_VALUE1 = {16{8'hA5}};

    always_ff @(posedge user_clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_cyc        <= 0;
            wb_stb        <= 0;
            wb_we         <= 0;
            wb_addr       <= 0;
            wb_data_i     <= 0;
            delay_counter <= 0;
            test_pass     <= 0;
            test_state    <= TST_IDLE;
        end else begin
            case (test_state)
                TST_IDLE: begin
                    wb_data_i  <= TEST_VALUE;
                    wb_addr    <= 32'h00000000;
                    wb_we      <= 1;
                    wb_stb     <= 1;
                    wb_cyc     <= 1;
                    test_state <= TST_WRITE;
                end
                TST_WRITE: begin
                    if (wb_ack) begin
                        wb_stb        <= 0;
                        wb_we         <= 0;
                        wb_cyc        <= 0;
                        delay_counter <= 0;
                        test_state    <= TST_WAIT_WRITE;
                    end
                end
                TST_WAIT_WRITE: begin
                    if (delay_counter == 5000) begin
                        wb_stb     <= 1;
                        wb_cyc     <= 1;
                        wb_we      <= 0;
                        test_state <= TST_READ;
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                TST_READ: begin
                    if (wb_ack) begin
                        wb_stb     <= 0;
                        wb_cyc     <= 0;
                        test_state <= TST_CHECK;
                    end
                end
                TST_CHECK: begin
                    if (wb_data_o == TEST_VALUE)
                        test_pass <= 1;
                    test_state <= TST_CHECK;
                end
                default: test_state <= TST_IDLE;
            endcase
        end
    end

    always_ff @(posedge user_clk or negedge rst_n) begin
        if (!rst_n) begin
            led <= 8'b0;
        end else begin
            led <= {7'b0, test_pass};
        end
    end

endmodule
