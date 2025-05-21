module DRAM_Controller #(
    parameter USER_CLK_FREQ = 100_000_000,
    parameter REF_CLK_FREQ  = 200_000_000,
    parameter DRAM_CLK_FREQ = 800_000_000,
    parameter WORD_SIZE     = 128
) (
    // System clk interface
    input  logic                   user_clk_i,     // User clk - 100_000_000
    input  logic                   rst_n_i,
    
    // Wishbone Interface
    input  logic                   cyc_i,          // Wishbone cycle indicator
    input  logic                   stb_i,          // Wishbone strobe (request)
    input  logic                   we_i,           // Write enable

    input  logic [31:0]            addr_i,         // Address input
    input  logic [WORD_SIZE - 1:0] data_i,         // Data input (for write)
    output logic [WORD_SIZE - 1:0] data_o,         // Data output (for read)
    output logic                   ack_o,          // Acknowledge output

    // DRAM clk interface
    input  logic                   ddr3_clk_i,     // DDR3 clock
    input  logic                   ddr3_ref_clk_i, // DDR3 reference clock

    // DRAM interface
    inout  logic [31:0]            ddr3_dq,
    inout  logic [3:0]             ddr3_dqs_n,
    inout  logic [3:0]             ddr3_dqs_p,
    output logic [14:0]            ddr3_addr,
    output logic [2:0]             ddr3_ba,
    output logic                   ddr3_ras_n,
    output logic                   ddr3_cas_n,
    output logic                   ddr3_we_n,
    output logic                   ddr3_reset_n,
    output logic [0:0]             ddr3_ck_p,
    output logic [0:0]             ddr3_ck_n,
    output logic [0:0]             ddr3_cke,
    output logic [0:0]             ddr3_cs_n,
    output logic [3:0]             ddr3_dm,
    output logic [0:0]             ddr3_odt

);
    logic rst_n;
    assign rst_n = rst_n_i;

    logic ui_clk, ui_clk_sync_rst;
    logic calib_done;

    typedef struct packed {
        logic         we;
        logic [31:0]  addr;
        logic [WORD_SIZE-1:0] data;
    } req_t;

    typedef struct packed {
        logic [WORD_SIZE-1:0] data;
    } resp_t;

    req_t  req_fifo_wdata, req_fifo_rdata;
    logic  req_fifo_full, req_fifo_empty;
    logic  req_fifo_wr_en, req_fifo_rd_en;

    resp_t resp_fifo_wdata, resp_fifo_rdata;
    logic  resp_fifo_full, resp_fifo_empty;
    logic  resp_fifo_wr_en, resp_fifo_rd_en;

    // Async FIFOs
    async_fifo #(
        .DEPTH        (32), 
        .WIDTH        ($bits(req_t))
    ) request_fifo (
        .clk_wr       (user_clk_i),
        .clk_rd       (ui_clk),
        .rst_n        (rst_n),
        .wr_en_i      (req_fifo_wr_en),
        .rd_en_i      (req_fifo_rd_en),
        .write_data_i (req_fifo_wdata),
        .read_data_o  (req_fifo_rdata),
        .full_o       (req_fifo_full),
        .empty_o      (req_fifo_empty)
    );

    async_fifo #(
        .DEPTH        (32),
        .WIDTH        ($bits(resp_t))
    ) response_fifo (
        .clk_wr       (ui_clk),
        .clk_rd       (user_clk_i),
        .rst_n        (rst_n),
        .wr_en_i      (resp_fifo_wr_en),
        .rd_en_i      (resp_fifo_rd_en),
        .write_data_i (resp_fifo_wdata),
        .read_data_o  (resp_fifo_rdata),
        .full_o       (resp_fifo_full),
        .empty_o      (resp_fifo_empty)
    );

    // Wishbone FSM (user_clk)
    typedef enum logic [1:0] {
        WB_IDLE,
        WB_REQ,
        WB_WAIT_RESP,
        WB_ACK
    } wb_state_t;

    wb_state_t wb_state, wb_next;

    always_ff @(posedge user_clk_i or negedge rst_n) begin
        if (!rst_n) 
            wb_state <= WB_IDLE;
        else
            wb_state <= wb_next;
    end

    always_comb begin
        wb_next         = wb_state;
        req_fifo_wr_en  = 0;
        req_fifo_wdata  = '{default:0};
        resp_fifo_rd_en = 0;
        ack_o           = 0;
        data_o          = 0;

        case (wb_state)
            WB_IDLE: begin
                if (cyc_i && stb_i && !req_fifo_full) begin
                    wb_next = WB_REQ;
                end
            end
            WB_REQ: begin
                req_fifo_wdata = '{we: we_i, addr: addr_i, data: data_i};
                req_fifo_wr_en = 1;
                wb_next        = we_i ? WB_ACK : WB_WAIT_RESP;
            end
            WB_WAIT_RESP: begin
                if (!resp_fifo_empty) begin
                    resp_fifo_rd_en = 1;
                    wb_next         = WB_ACK;
                end
            end
            WB_ACK: begin
                ack_o  = 1;
                data_o = resp_fifo_rdata.data;
                if (!(cyc_i && stb_i)) wb_next = WB_IDLE;
            end
        endcase
    end

    // MIG FSM (ui_clk)
    typedef enum logic [2:0] {
        MIG_IDLE,
        MIG_READ,
        MIG_WRITE,
        MIG_WAIT_RD,
        MIG_RESP
    } mig_state_t;

    mig_state_t mig_state, mig_next;

    always_ff @(posedge ui_clk or posedge ui_clk_sync_rst) begin
        if (ui_clk_sync_rst) 
            mig_state <= MIG_IDLE;
        else                 
            mig_state <= mig_next;
    end

    logic [28:0] app_addr;
    logic [2:0]  app_cmd;
    logic        app_en, app_wdf_end, app_wdf_wren;
    logic [WORD_SIZE-1:0] app_wdf_data, app_rd_data;
    logic        app_rd_data_valid, app_rdy, app_wdf_rdy;

    assign app_wdf_end  = 1'b1;
    assign app_addr     = req_fifo_rdata.addr[31:3];
    assign app_wdf_data = req_fifo_rdata.data;
    assign app_cmd      = (mig_state == MIG_READ) ? 3'b001 : 3'b000;

    always_comb begin
        mig_next        = mig_state;
        req_fifo_rd_en  = 0;
        app_en          = 0;
        app_wdf_wren    = 0;
        resp_fifo_wr_en = 0;
        resp_fifo_wdata = '{default:0};

        case (mig_state)
            MIG_IDLE: begin
                if (calib_done && !req_fifo_empty) begin
                    if (req_fifo_rdata.we) mig_next = MIG_WRITE;
                    else                   mig_next = MIG_READ;
                end
            end
            MIG_WRITE: begin
                if (app_rdy && app_wdf_rdy) begin
                    app_en         = 1;
                    app_wdf_wren   = 1;
                    req_fifo_rd_en = 1;
                    mig_next       = MIG_IDLE;
                end
            end
            MIG_READ: begin
                if (app_rdy) begin
                    app_en         = 1;
                    req_fifo_rd_en = 1;
                    mig_next       = MIG_WAIT_RD;
                end
            end
            MIG_WAIT_RD: begin
                if (app_rd_data_valid) begin
                    resp_fifo_wdata.data = app_rd_data;
                    resp_fifo_wr_en      = 1;
                    mig_next             = MIG_IDLE;
                end
            end
        endcase
    end

    mig_7series_0 mig_7series_0_inst (
        // Memory signals
        .ddr3_dq             (ddr3_dq),
        .ddr3_dqs_n          (ddr3_dqs_n),
        .ddr3_dqs_p          (ddr3_dqs_p),
        .ddr3_addr           (ddr3_addr),
        .ddr3_ba             (ddr3_ba),
        .ddr3_ras_n          (ddr3_ras_n),
        .ddr3_cas_n          (ddr3_cas_n),
        .ddr3_we_n           (ddr3_we_n),
        .ddr3_reset_n        (ddr3_reset_n),
        .ddr3_ck_p           (ddr3_ck_p),
        .ddr3_ck_n           (ddr3_ck_n),
        .ddr3_cke            (ddr3_cke),

        .ddr3_cs_n           (ddr3_cs_n),
        .ddr3_dm             (ddr3_dm),
        .ddr3_odt            (ddr3_odt),

        // Application signals
        .app_addr            (app_addr),
        .app_cmd             (app_cmd),
        .app_en              (app_en),
        .app_wdf_data        (app_wdf_data),
        .app_wdf_end         (app_wdf_end),
        .app_wdf_mask        (32'd0),
        .app_wdf_wren        (app_wdf_wren),
        .app_rd_data         (app_rd_data),
        .app_rd_data_end     (app_rd_data_end),
        .app_rd_data_valid   (app_rd_data_valid),
        .app_rdy             (app_rdy),
        .app_wdf_rdy         (app_wdf_rdy),
        .app_sr_req          ('b0),
        .app_ref_req         ('b0),
        .app_zq_req          ('b0),
        .app_sr_active       (app_sr_active),
        .app_ref_ack         (app_ref_ack),
        .app_zq_ack          (app_zq_ac),

        .ui_clk              (ui_clk),
        .ui_clk_sync_rst     (ui_clk_sync_rst),

        // Sys signals
        .sys_clk_i           (ddr3_clk_i),
        .clk_ref_i           (ddr3_ref_clk_i),
        .init_calib_complete (calib_done),
        .device_temp         (),
        .sys_rst             (!rst_n_i)
    );    
    
endmodule
