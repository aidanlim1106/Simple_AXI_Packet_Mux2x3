import param_pkg::*;

module stat_counters (
    input logic                     aclk,
    input logic                     aresetn,

    input  logic                    data_accept,
    input  logic                    pkt_complete, // tlast
    input  logic                    source, // 0=M0, 1=M1
    input  dst_t                    dst, 
    input  logic                    drop_pkt,
    input  logic [KEEP_WIDTH-1:0]   tkeep,

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

    // count 1's in tkeep
    logic [2:0] bytes_this_cycle;
    assign bytes_this_cycle = tkeep[0] + tkeep[1] + tkeep[2] + tkeep[3];

    // packet completion
    logic m0_pkt_done;
    logic m1_pkt_done;
    logic m0_dropped;
    logic m1_dropped;
    logic s0_pkt_done;
    logic s1_pkt_done;
    logic s2_pkt_done;

    assign m0_pkt_done = pkt_complete && (source == 1'b0) && !drop_pkt;
    assign m1_pkt_done = pkt_complete && (source == 1'b1) && !drop_pkt;
    assign m0_dropped  = pkt_complete && (source == 1'b0) && drop_pkt;
    assign m1_dropped  = pkt_complete && (source == 1'b1) && drop_pkt;
    assign s0_pkt_done = pkt_complete && (dst == DST_S0) && !drop_pkt;
    assign s1_pkt_done = pkt_complete && (dst == DST_S1) && !drop_pkt;
    assign s2_pkt_done = pkt_complete && (dst == DST_S2) && !drop_pkt;

    // byte completion
    logic m0_byte_en;
    logic m1_byte_en;
    logic s0_byte_en;
    logic s1_byte_en;
    logic s2_byte_en;

    assign m0_byte_en = data_accept && (source == 1'b0);
    assign m1_byte_en = data_accept && (source == 1'b1);
    assign s0_byte_en = data_accept && (dst == DST_S0) && !drop_pkt;
    assign s1_byte_en = data_accept && (dst == DST_S1) && !drop_pkt;
    assign s2_byte_en = data_accept && (dst == DST_S2) && !drop_pkt;

    // counter logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m0_pkt_count   <= '0;
            m0_byte_count  <= '0;
            m0_pkt_dropped <= '0;
            m1_pkt_count   <= '0;
            m1_byte_count  <= '0;
            m1_pkt_dropped <= '0;
            s0_pkt_count   <= '0;
            s0_byte_count  <= '0;
            s1_pkt_count   <= '0;
            s1_byte_count  <= '0;
            s2_pkt_count   <= '0;
            s2_byte_count  <= '0;
        end else begin
            // m0
            if (m0_pkt_done)
                m0_pkt_count <= m0_pkt_count + 1;
            if (m0_byte_en)
                m0_byte_count <= m0_byte_count + bytes_this_cycle;
            if (m0_dropped)
                m0_pkt_dropped <= m0_pkt_dropped + 1; 

            // m1
            if (m1_pkt_done)
                m1_pkt_count <= m1_pkt_count + 1;
            if (m1_byte_en)
                m1_byte_count <= m1_byte_count + bytes_this_cycle;
            if (m1_dropped)
                m1_pkt_dropped <= m1_pkt_dropped + 1;

            // s0
            if (s0_pkt_done)
                s0_pkt_count <= s0_pkt_count + 1;
            if (s0_byte_en)
                s0_byte_count <= s0_byte_count + bytes_this_cycle;

            // s1
            if (s1_pkt_done)
                s1_pkt_count <= s1_pkt_count + 1;
            if (s1_byte_en)
                s1_byte_count <= s1_byte_count + bytes_this_cycle;

            // s2
            if (s2_pkt_done)
                s2_pkt_count <= s2_pkt_count + 1;
            if (s2_byte_en)
                s2_byte_count <= s2_byte_count + bytes_this_cycle;
        end
    end

endmodule