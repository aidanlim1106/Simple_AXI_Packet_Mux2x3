import param_pkg::*;

module packet_mux_toplvl (
    input logic                     aclk,
    input logic                     aresetn,

    // m0
    input  logic [DATA_WIDTH-1:0]   m0_tdata,
    input  logic [KEEP_WIDTH-1:0]   m0_tkeep,
    input  logic                    m0_tvalid,
    input  logic                    m0_tlast,
    output logic                    m0_tready,

    // m1
    input  logic [DATA_WIDTH-1:0]   m1_tdata,
    input  logic [KEEP_WIDTH-1:0]   m1_tkeep,
    input  logic                    m1_tvalid,
    input  logic                    m1_tlast,
    output logic                    m1_tready,

    // s0
    output logic [DATA_WIDTH-1:0]   s0_tdata,
    output logic [KEEP_WIDTH-1:0]   s0_tkeep,
    output logic                    s0_tvalid,
    output logic                    s0_tlast,
    input logic                     s0_tready,

    // s1
    output logic [DATA_WIDTH-1:0]   s1_tdata,
    output logic [KEEP_WIDTH-1:0]   s1_tkeep,
    output logic                    s1_tvalid,
    output logic                    s1_tlast,
    input  logic                    s1_tready,

    // s2
    output logic [DATA_WIDTH-1:0]   s2_tdata,
    output logic [KEEP_WIDTH-1:0]   s2_tkeep,
    output logic                    s2_tvalid,
    output logic                    s2_tlast,
    input  logic                    s2_tready,

    // error outputs
    output logic                    illegal_dst_error,
    output logic                    pkt_len_error,
    output logic                    error_catch,

    // master counters
    output logic [31:0]             m0_pkt_count,
    output logic [31:0]             m0_byte_count,
    output logic [31:0]             m0_pkt_dropped,
    output logic [31:0]             m1_pkt_count,
    output logic [31:0]             m1_byte_count,
    output logic [31:0]             m1_pkt_dropped,

    // slave counters
    output logic [31:0]             s0_pkt_count,
    output logic [31:0]             s0_byte_count,
    output logic [31:0]             s1_pkt_count,
    output logic [31:0]             s1_byte_count,
    output logic [31:0]             s2_pkt_count,
    output logic [31:0]             s2_byte_count
);

    // arb -> router
    logic [DATA_WIDTH-1:0]  arb_tdata;
    logic [KEEP_WIDTH-1:0]  arb_tkeep;
    logic                   arb_tvalid;
    logic                   arb_tlast;
    logic                   arb_tready;
    logic                   arb_selected;

    // router signals
    router_state_t          state;
    router_state_t          state_next;
    ctrl_processed_t        ctrl_reg;
    logic                   drop_pkt;

    logic [LEN_WIDTH:0]     words_expected;
    logic [LEN_WIDTH:0]     words_received;

    logic ctrl_accept;
    assign ctrl_accept = (state == ROUTER_IDLE) && arb_tvalid && arb_tready;

    logic data_accept;
    assign data_accept = (state == ROUTER_DATA) && arb_tvalid && arb_tready;

    logic pkt_complete;
    assign pkt_complete = data_accept && arb_tlast;

    // master round robin instantiation
    rr_arbiter_2x1 u_arbiter (
        .aclk         (aclk),
        .aresetn      (aresetn),

        .m0_tdata     (m0_tdata),
        .m0_tkeep     (m0_tkeep),
        .m0_tvalid    (m0_tvalid),
        .m0_tlast     (m0_tlast),
        .m0_tready    (m0_tready),

        .m1_tdata     (m1_tdata),
        .m1_tkeep     (m1_tkeep),
        .m1_tvalid    (m1_tvalid),
        .m1_tlast     (m1_tlast),
        .m1_tready    (m1_tready),

        .arb_tdata    (arb_tdata),
        .arb_tkeep    (arb_tkeep),
        .arb_tvalid   (arb_tvalid),
        .arb_tlast    (arb_tlast),
        .arb_tready   (arb_tready),
        .arb_selected (arb_selected)
    );

    // counter instantiation
    stat_counters u_stats (
        .aclk           (aclk),
        .aresetn        (aresetn),

        .data_accept    (data_accept),
        .pkt_complete   (pkt_complete),
        .source         (ctrl_reg.source),
        .dst            (ctrl_reg.dst),
        .drop_pkt       (drop_pkt),
        .tkeep          (arb_tkeep),

        .m0_pkt_count   (m0_pkt_count),
        .m0_byte_count  (m0_byte_count),
        .m0_pkt_dropped (m0_pkt_dropped),
        .m1_pkt_count   (m1_pkt_count),
        .m1_byte_count  (m1_byte_count),
        .m1_pkt_dropped (m1_pkt_dropped),

        .s0_pkt_count   (s0_pkt_count),
        .s0_byte_count  (s0_byte_count),
        .s1_pkt_count   (s1_pkt_count),
        .s1_byte_count  (s1_byte_count),
        .s2_pkt_count   (s2_pkt_count),
        .s2_byte_count  (s2_byte_count)
    );

    // error registers
    logic illegal_dst_error_reg;
    logic early_tlast_error_reg; 
    logic late_tlast_error_reg;

    assign illegal_dst_error = illegal_dst_error_reg;
    assign pkt_len_error     = early_tlast_error_reg | late_tlast_error_reg;
    assign error_catch       = illegal_dst_error_reg | early_tlast_error_reg | late_tlast_error_reg;

    wire [LEN_WIDTH:0] words_after_this_beat = words_received + 1;

    logic early_tlast_detected;
    assign early_tlast_detected = data_accept && arb_tlast && 
                                  (words_after_this_beat < words_expected);

    logic late_tlast_detected;
    assign late_tlast_detected = data_accept && !arb_tlast && 
                                 (words_after_this_beat >= words_expected);

    // sequential logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state                 <= ROUTER_IDLE;
            ctrl_reg              <= '0;
            words_expected        <= '0;
            words_received        <= '0;
            illegal_dst_error_reg <= 1'b0;
            early_tlast_error_reg <= 1'b0;
            late_tlast_error_reg  <= 1'b0;
            drop_pkt              <= 1'b0;
        end else begin
            state <= state_next;

            if (ctrl_accept) begin
                ctrl_reg.source     <= arb_selected;
                ctrl_reg.dst        <= dst_t'(arb_tdata[DST_MSB:DST_LSB]);
                ctrl_reg.num_words  <= arb_tdata[LEN_MSB:LEN_LSB];
                drop_pkt            <= (dst_t'(arb_tdata[DST_MSB:DST_LSB]) == DST_ILL);

                // Set expected words (handle 0 = 4096 case)
                if (arb_tdata[LEN_MSB:LEN_LSB] == '0)
                    words_expected <= 13'd4096;
                else
                    words_expected <= {1'b0, arb_tdata[LEN_MSB:LEN_LSB]};

                // Reset received counter
                words_received <= '0;

                if (dst_t'(arb_tdata[DST_MSB:DST_LSB]) == DST_ILL)
                    illegal_dst_error_reg <= 1'b1;
            end

            // Count received words
            if (data_accept)
                words_received <= words_received + 1;

            // Reset on packet complete
            if (pkt_complete)
                words_received <= '0;

            if (early_tlast_detected)
                early_tlast_error_reg <= 1'b1;
            
            if (late_tlast_detected)
                late_tlast_error_reg <= 1'b1;
        end
    end

    // combinational logic
    always_comb begin
        state_next = state;
        arb_tready = 1'b0;

        s0_tdata   = '0;
        s0_tkeep   = '0;
        s0_tvalid  = 1'b0;
        s0_tlast   = 1'b0;

        s1_tdata   = '0;
        s1_tkeep   = '0;
        s1_tvalid  = 1'b0;
        s1_tlast   = 1'b0;

        s2_tdata   = '0;
        s2_tkeep   = '0;
        s2_tvalid  = 1'b0;
        s2_tlast   = 1'b0;

        case (state)
            ROUTER_IDLE: begin
                arb_tready = 1'b1;
                if (arb_tvalid) 
                    state_next = ROUTER_PROCESS;
                else 
                    state_next = ROUTER_IDLE;
            end

            ROUTER_PROCESS: begin
                state_next = ROUTER_DATA;
            end

            ROUTER_DATA: begin
                if (drop_pkt) begin
                    arb_tready = 1'b1;
                end else begin
                    case (ctrl_reg.dst)
                        DST_S0: begin 
                            arb_tready = s0_tready;
                            s0_tvalid  = arb_tvalid;
                            s0_tdata   = arb_tdata;
                            s0_tkeep   = arb_tkeep;
                            s0_tlast   = arb_tlast;
                        end

                        DST_S1: begin
                            arb_tready = s1_tready;
                            s1_tvalid  = arb_tvalid;
                            s1_tdata   = arb_tdata;
                            s1_tkeep   = arb_tkeep;
                            s1_tlast   = arb_tlast;  
                        end

                        DST_S2: begin
                            arb_tready = s2_tready;
                            s2_tvalid  = arb_tvalid;
                            s2_tdata   = arb_tdata;
                            s2_tkeep   = arb_tkeep;
                            s2_tlast   = arb_tlast;
                        end

                        default: begin
                            arb_tready = 1'b1;
                        end
                    endcase
                end

                if (data_accept && arb_tlast)
                    state_next = ROUTER_IDLE;
                else
                    state_next = ROUTER_DATA;
            end

            default: begin
                state_next = ROUTER_IDLE;
            end
        endcase
    end

endmodule