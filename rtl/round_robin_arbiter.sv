import param_pkg::*;

module rr_arbiter_2x1 (
    input logic        aclk,
    input logic        aresetn,

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

    // output
    output logic [DATA_WIDTH-1:0]   arb_tdata,
    output logic [KEEP_WIDTH-1:0]   arb_tkeep,
    output logic                    arb_tvalid,
    output logic                    arb_tlast,
    input  logic                    arb_tready,

    output logic                    arb_selected
);

    typedef enum logic [1:0] {
        ARB_IDLE,
        ARB_GRANT_M0,
        ARB_GRANT_M1
    } arb_state_t;

    arb_state_t state;
    arb_state_t state_next;

    logic granted_last;
    logic m0_complete;
    logic m1_complete;

    assign m0_complete = m0_tvalid && m0_tready && m0_tlast;
    assign m1_complete = m1_tvalid && m1_tready && m1_tlast;

    // sequential logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= ARB_IDLE;
            granted_last <= 1'b0;
        end else begin
            state <= state_next;

            if (state == ARB_GRANT_M0 && m0_complete) 
                granted_last <= 1'b0;
            else if (state == ARB_GRANT_M1 && m1_complete)
                granted_last <= 1'b1;
        end
    end

    // combinational logic
    always_comb begin
        state_next = state;
        m0_tready  = 1'b0;
        m1_tready  = 1'b0;
        arb_tdata  = '0;
        arb_tkeep  = '0;
        arb_tvalid = 1'b0;
        arb_tlast  = 1'b0;
        arb_selected = 1'b0;

        case (state)
            ARB_IDLE: begin
                if (m0_tvalid && m1_tvalid) begin
                    if (granted_last == 1'b0) // m0 was last, m1s turn
                        state_next = ARB_GRANT_M1;
                    else
                        state_next = ARB_GRANT_M0;
                end else if (m0_tvalid)
                    state_next = ARB_GRANT_M0;
                else if (m1_tvalid)
                    state_next = ARB_GRANT_M1;
                else   
                    state_next = ARB_IDLE;
            end

            ARB_GRANT_M0: begin
                arb_tdata  = m0_tdata;
                arb_tkeep  = m0_tkeep;
                arb_tvalid = m0_tvalid;
                arb_tlast  = m0_tlast;
                arb_selected = 1'b0;

                // backpressure
                m0_tready = arb_tready;

                if (m0_complete)
                    state_next = ARB_IDLE;
                else 
                    state_next = ARB_GRANT_M0;
            end

            ARB_GRANT_M1: begin
                arb_tdata  = m1_tdata;
                arb_tkeep  = m1_tkeep;
                arb_tvalid = m1_tvalid;
                arb_tlast  = m1_tlast;
                arb_selected = 1'b1;

                m1_tready = arb_tready;

                if (m1_complete)
                    state_next = ARB_IDLE;
                else 
                    state_next = ARB_GRANT_M1;
            end

            default: begin
                state_next = ARB_IDLE;
            end
        endcase
    end

endmodule