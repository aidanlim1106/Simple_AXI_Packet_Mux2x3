module tb_packet_mux;

    import param_pkg::*;

    logic aclk;
    logic aresetn;

    // master 
    logic [data_WIDTH-1:0] master_tdata;
    logic [KEEP_WIDTH-1:0] master_tkeep;
    logic                  master_tvalid;
    logic                  master_tlast;
    logic                  master_tready;

    // s0 
    logic [data_WIDTH-1:0] s0_tdata;
    logic [KEEP_WIDTH-1:0] s0_tkeep;
    logic                  s0_tvalid;
    logic                  s0_tlast;
    logic                  s0_tready;

    // s1 
    logic [data_WIDTH-1:0] s1_tdata;
    logic [KEEP_WIDTH-1:0] s1_tkeep;
    logic                  s1_tvalid;
    logic                  s1_tlast;
    logic                  s1_tready;

    // s2 
    logic [data_WIDTH-1:0] s2_tdata;
    logic [KEEP_WIDTH-1:0] s2_tkeep;
    logic                  s2_tvalid;
    logic                  s2_tlast;
    logic                  s2_tready;

    logic illegal_dst_error;

    int tests_passed = 0;
    int tests_failed = 0;

    packet_mux_toplvl dut (
        .aclk             (aclk),
        .aresetn          (aresetn),

        .master_tdata     (master_tdata),
        .master_tkeep     (master_tkeep),
        .master_tvalid    (master_tvalid),
        .master_tlast     (master_tlast),
        .master_tready    (master_tready),

        .s0_tdata         (s0_tdata),
        .s0_tkeep         (s0_tkeep),
        .s0_tvalid        (s0_tvalid),
        .s0_tlast         (s0_tlast),
        .s0_tready        (s0_tready),

        .s1_tdata         (s1_tdata),
        .s1_tkeep         (s1_tkeep),
        .s1_tvalid        (s1_tvalid),
        .s1_tlast         (s1_tlast),
        .s1_tready        (s1_tready),

        .s2_tdata         (s2_tdata),
        .s2_tkeep         (s2_tkeep),
        .s2_tvalid        (s2_tvalid),
        .s2_tlast         (s2_tlast),
        .s2_tready        (s2_tready),

        .illegal_dst_error(illegal_dst_error)
    );

    // 10 ns period
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end

    initial begin
        $display("[%0t] TB: Starting simulation", $time);
        // Enhanced debug monitor - shows all slaves
        $monitor("[%0t] STATE=%0d ctrl_dst=%0d drop_pkt=%0b words_rem=%0d | M: v=%0b r=%0b d=0x%08h last=%0b | s0: v=%0b d=0x%08h | s1: v=%0b d=0x%08h | s2: v=%0b d=0x%08h | err=%0b",
                 $time,
                 dut.state, 
                 dut.ctrl_reg.dst, 
                 dut.drop_pkt,
                 dut.words_rem,
                 master_tvalid, master_tready, master_tdata, master_tlast,
                 s0_tvalid, s0_tdata,
                 s1_tvalid, s1_tdata,
                 s2_tvalid, s2_tdata,
                 illegal_dst_error);
    end

    initial begin
        aresetn       = 0;
        master_tdata  = '0;
        master_tkeep  = '0;
        master_tvalid = 0;
        master_tlast  = 0;
        s0_tready     = 1;
        s1_tready     = 1;
        s2_tready     = 1;

        #25;
        aresetn = 1;
        $display("[%0t] TB: Reset deasserted", $time);

        #20;

        // PACKET 1: Valid destination (DST_s0), length=3
        $display("[%0t] TB: === PACKET 1: Valid DST_s0, length=3 ===", $time);

        // CONTROL WORD: dest=DST_s0 (00), length=3
        master_tdata  = 32'h0000_0003;
        master_tkeep  = '1;       
        master_tlast  = 0;
        master_tvalid = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: Control word accepted: tdata=0x%08h", $time, master_tdata);
        @(posedge aclk); 

        // data cycle 1
        master_tdata  = 32'hAAAA_0001;
        master_tkeep  = '1;
        master_tlast  = 0;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 1 accepted: tdata=0x%08h", $time, master_tdata);
        
        // Check routing to s0
        if (s0_tvalid && !s1_tvalid && !s2_tvalid && s0_tdata == 32'hAAAA_0001) begin
            $display("[%0t] TB: CHECK s0 routing [PASS]", $time);
            tests_passed++;
        end else begin
            $display("[%0t] TB: CHECK s0 routing [FAIL] - s0_v=%0b s1_v=%0b s2_v=%0b", $time, s0_tvalid, s1_tvalid, s2_tvalid);
            tests_failed++;
        end
        
        @(posedge aclk);

        // data cycle 2
        master_tdata  = 32'hAAAA_0002;
        master_tkeep  = '1;
        master_tlast  = 0;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 2 accepted: tdata=0x%08h", $time, master_tdata);
        @(posedge aclk);

        // data cycle 3 (LAST)
        master_tdata  = 32'hAAAA_0003;
        master_tkeep  = '1;
        master_tlast  = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 3 (LAST) accepted: tdata=0x%08h", $time, master_tdata);

        // End of packet: deassert valid/last
        master_tvalid = 0;
        master_tlast  = 0;

        @(posedge aclk);

        #20;
        $display("[%0t] TB: Packet 1 done, state should be IDLE, words_rem==0", $time);

        // PACKET 2: Valid destination (DST_s1), length=2
        $display("[%0t] TB: === PACKET 2: Valid DST_s1, length=2 ===", $time);

        // CONTROL WORD: dest=DST_s1 (01), length=2
        // Bits [13:12] = 01, Bits [11:0] = 2 => 0x1002
        master_tdata  = 32'h0000_1002;
        master_tkeep  = '1;
        master_tlast  = 0;
        master_tvalid = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: Control word accepted: tdata=0x%08h (dst bits[13:12]=%02b)", 
                 $time, master_tdata, master_tdata[13:12]);
        @(posedge aclk);

        // data cycle 1
        master_tdata  = 32'hBBBB_0001;
        master_tkeep  = '1;
        master_tlast  = 0;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 1 accepted: tdata=0x%08h", $time, master_tdata);
        
        // Check routing to s1
        if (!s0_tvalid && s1_tvalid && !s2_tvalid && s1_tdata == 32'hBBBB_0001) begin
            $display("[%0t] TB: CHECK s1 routing [PASS]", $time);
            tests_passed++;
        end else begin
            $display("[%0t] TB: CHECK s1 routing [FAIL] - s0_v=%0b s1_v=%0b s2_v=%0b", $time, s0_tvalid, s1_tvalid, s2_tvalid);
            tests_failed++;
        end
        
        @(posedge aclk);

        // data cycle 2 (LAST)
        master_tdata  = 32'hBBBB_0002;
        master_tkeep  = '1;
        master_tlast  = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 2 (LAST) accepted: tdata=0x%08h", $time, master_tdata);

        master_tvalid = 0;
        master_tlast  = 0;

        @(posedge aclk);

        #20;
        $display("[%0t] TB: Packet 2 done", $time);

        // PACKET 3: Valid destination (DST_s2), length=2
        $display("[%0t] TB: === PACKET 3: Valid DST_s2, length=2 ===", $time);

        // CONTROL WORD: dest=DST_s2 (10), length=2
        // Bits [13:12] = 10, Bits [11:0] = 2 => 0x2002
        master_tdata  = 32'h0000_2002;
        master_tkeep  = '1;
        master_tlast  = 0;
        master_tvalid = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: Control word accepted: tdata=0x%08h (dst bits[13:12]=%02b)", 
                 $time, master_tdata, master_tdata[13:12]);
        @(posedge aclk);

        // data cycle 1
        master_tdata  = 32'hCCCC_0001;
        master_tkeep  = '1;
        master_tlast  = 0;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 1 accepted: tdata=0x%08h", $time, master_tdata);
        
        // Check routing to s2
        if (!s0_tvalid && !s1_tvalid && s2_tvalid && s2_tdata == 32'hCCCC_0001) begin
            $display("[%0t] TB: CHECK s2 routing [PASS]", $time);
            tests_passed++;
        end else begin
            $display("[%0t] TB: CHECK s2 routing [FAIL] - s0_v=%0b s1_v=%0b s2_v=%0b", $time, s0_tvalid, s1_tvalid, s2_tvalid);
            tests_failed++;
        end
        
        @(posedge aclk);

        // data cycle 2 (LAST)
        master_tdata  = 32'hCCCC_0002;
        master_tkeep  = '1;
        master_tlast  = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: data cycle 2 (LAST) accepted: tdata=0x%08h", $time, master_tdata);

        master_tvalid = 0;
        master_tlast  = 0;

        @(posedge aclk);

        #20;
        $display("[%0t] TB: Packet 3 done", $time);

        // PACKET 4: Illegal destination (DST_ILL), length=2
        $display("[%0t] TB: === PACKET 4: Illegal DST_ILL, length=2 ===", $time);

        // CONTROL WORD: dest=DST_ILL (11), length=2
        // Bits [13:12] = 11, Bits [11:0] = 2 => 0x3002
        master_tdata  = 32'h0000_3002;
        master_tkeep  = '1;
        master_tlast  = 0;
        master_tvalid = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: Illegal control word accepted: tdata=0x%08h (dst bits[13:12]=%02b)", 
                 $time, master_tdata, master_tdata[13:12]);
        @(posedge aclk);

        // data cycle 1 (should be DROPPED)
        master_tdata  = 32'hDEAD_0001;
        master_tkeep  = '1;
        master_tlast  = 0;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: Illegal data cycle 1 accepted (should NOT appear at any slave): tdata=0x%08h", $time, master_tdata);
        
        // Check all slaves have tvalid=0
        if (!s0_tvalid && !s1_tvalid && !s2_tvalid) begin
            $display("[%0t] TB: CHECK illegal packet dropped [PASS]", $time);
            tests_passed++;
        end else begin
            $display("[%0t] TB: CHECK illegal packet dropped [FAIL] - s0_v=%0b s1_v=%0b s2_v=%0b", $time, s0_tvalid, s1_tvalid, s2_tvalid);
            tests_failed++;
        end
        
        @(posedge aclk);

        // data cycle 2 (LAST, also should be DROPPED)
        master_tdata  = 32'hDEAD_0002;
        master_tkeep  = '1;
        master_tlast  = 1;

        @(posedge aclk);
        wait (master_tready && master_tvalid);
        $display("[%0t] TB: Illegal data cycle 2 (LAST) accepted (should NOT appear at any slave): tdata=0x%08h", $time, master_tdata);

        master_tvalid = 0;
        master_tlast  = 0;

        @(posedge aclk);
        
        // Check error flag
        if (illegal_dst_error) begin
            $display("[%0t] TB: CHECK illegal_dst_error flag [PASS]", $time);
            tests_passed++;
        end else begin
            $display("[%0t] TB: CHECK illegal_dst_error flag [FAIL] - expected 1, got %0b", $time, illegal_dst_error);
            tests_failed++;
        end

        #20;
        $display("[%0t] TB: Packet 4 done", $time);

        // TEST SUMMARY
        #50;
        $display("");
        $display("[%0t] TB: TEST SUMMARY: %0d passed, %0d failed", $time, tests_passed, tests_failed);
        
        if (tests_failed == 0)
            $display("[%0t] TB: *** ALL TESTS PASSED! ***", $time);
        else
            $display("[%0t] TB: *** SOME TESTS FAILED! ***", $time);

        $display("[%0t] TB: Simulation finished", $time);
        $finish;
    end

    initial begin
        $dumpfile("packet_mux.vcd");
        $dumpvars(0, tb_packet_mux);
    end

endmodule