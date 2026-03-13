import param_pkg::*;

module packet_mux_toplvl (
    input logic                     aclk,
    input logic                     aresetn,

    // master
    input logic [DATA_WIDTH-1:0]    master_tdata,
    input logic [KEEP_WIDTH-1:0]    master_tkeep,
    input logic                     master_tvalid,
    input logic                     master_tlast,
    output logic                    master_tready,

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

    output logic                    illegal_dst_error
);

    router_state_t          state;
    router_state_t          state_next;
    ctrl_processed_t        ctrl_reg;
    logic [LEN_WIDTH:0]     words_rem;        
    logic                   illegal_dst_error_reg;
    logic                   drop_pkt;

    assign illegal_dst_error = illegal_dst_error_reg;

    logic ctrl_accept;
    assign ctrl_accept = (state == ROUTER_IDLE) && master_tvalid && master_tready;

    logic data_accept;
    assign data_accept = (state == ROUTER_DATA) && master_tvalid && master_tready;

    // sequential logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state       <= ROUTER_IDLE;
            ctrl_reg    <= '0;
            words_rem   <= '0;
            illegal_dst_error_reg <= 1'b0;
            drop_pkt    <= 1'b0;
        end else begin
            state <= state_next;

            if (ctrl_accept) begin
                ctrl_reg.source     <= 1'b0;                // ONE MASTER FOR NOW::: CHANGE LATER
                ctrl_reg.dst        <= dst_t'(master_tdata[DST_MSB:DST_LSB]);
                ctrl_reg.num_words  <= master_tdata[LEN_MSB:LEN_LSB];
                drop_pkt            <= (dst_t'(master_tdata[DST_MSB:DST_LSB]) == DST_ILL);

                if (master_tdata[LEN_MSB:LEN_LSB] == '0)
                    words_rem <= 13'd4096;
                else
                    words_rem <= {1'b0, master_tdata[LEN_MSB:LEN_LSB]};

                if (dst_t'(master_tdata[DST_MSB:DST_LSB]) == DST_ILL)
                    illegal_dst_error_reg <= 1'b1;
            end

            if (data_accept && (words_rem != '0)) 
                words_rem <= words_rem - 1;
        end
    end

    // combinational logic
    always_comb begin
        state_next = state;
        master_tready = 1'b0;

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
            ROUTER_IDLE:begin
                master_tready = 1'b1;
                if (master_tvalid) 
                    state_next = ROUTER_PROCESS;
                else 
                    state_next = ROUTER_IDLE;
            end

            ROUTER_PROCESS: begin
                state_next = ROUTER_DATA;
            end

            ROUTER_DATA: begin
                if (drop_pkt) begin
                    master_tready = 1'b1;
                    s0_tvalid = 1'b0;
                    s0_tdata   = '0;
                    s0_tkeep   = '0;
                    s0_tlast   = 1'b0;
                end else begin
                    unique case (ctrl_reg.dst)
                        DST_S0: begin 
                            //backpressure and pass AXI signals
                            master_tready = s0_tready;
                            s0_tvalid  = master_tvalid;
                            s0_tdata   = master_tdata;
                            s0_tkeep   = master_tkeep;
                            s0_tlast   = master_tlast;
                        end

                        DST_S1: begin
                            master_tready = s1_tready;
                            s1_tvalid  = master_tvalid;
                            s1_tdata   = master_tdata;
                            s1_tkeep   = master_tkeep;
                            s1_tlast   = master_tlast;  
                        end

                        DST_S2: begin
                            master_tready = s2_tready;
                            s2_tvalid  = master_tvalid;
                            s2_tdata   = master_tdata;
                            s2_tkeep   = master_tkeep;
                            s2_tlast   = master_tlast;
                        end

                        default: begin
                            master_tready = 1'b1;
                        end
                    endcase
                end

                if (data_accept && master_tlast)
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
