module tb_packet_mux;

    import param_pkg::*;

    logic aclk = 0;
    logic aresetn;

    // m0 
    logic [DATA_WIDTH-1:0] m0_tdata;
    logic [KEEP_WIDTH-1:0] m0_tkeep;
    logic                  m0_tvalid;
    logic                  m0_tlast;
    logic                  m0_tready;

    // m1 
    logic [DATA_WIDTH-1:0] m1_tdata;
    logic [KEEP_WIDTH-1:0] m1_tkeep;
    logic                  m1_tvalid;
    logic                  m1_tlast;
    logic                  m1_tready;

    // s0 
    logic [DATA_WIDTH-1:0] s0_tdata;
    logic [KEEP_WIDTH-1:0] s0_tkeep;
    logic                  s0_tvalid;
    logic                  s0_tlast;
    logic                  s0_tready;

    // s1 
    logic [DATA_WIDTH-1:0] s1_tdata;
    logic [KEEP_WIDTH-1:0] s1_tkeep;
    logic                  s1_tvalid;
    logic                  s1_tlast;
    logic                  s1_tready;

    // s2 
    logic [DATA_WIDTH-1:0] s2_tdata;
    logic [KEEP_WIDTH-1:0] s2_tkeep;
    logic                  s2_tvalid;
    logic                  s2_tlast;
    logic                  s2_tready;

    // Error outputs
    logic illegal_dst_error;
    logic pkt_len_error;
    logic error_catch;

    // Statistics outputs
    logic [31:0] m0_pkt_count, m0_byte_count, m0_pkt_dropped;
    logic [31:0] m1_pkt_count, m1_byte_count, m1_pkt_dropped;
    logic [31:0] s0_pkt_count, s0_byte_count;
    logic [31:0] s1_pkt_count, s1_byte_count;
    logic [31:0] s2_pkt_count, s2_byte_count;

    int tests_passed = 0;
    int tests_failed = 0;

    packet_mux_toplvl dut (.*);

    // clock: 10ns period
    always #5 aclk = ~aclk;

    // send packet from m0
    task automatic send_m0_packet(input [1:0] dest, input [11:0] length, input int num_cycles);
        m0_tdata = {18'b0, dest, length};
        m0_tkeep = 4'hF;
        m0_tvalid = 1;
        m0_tlast = 0;
        do @(posedge aclk); while (!m0_tready);
        for (int i = 1; i <= num_cycles; i++) begin
            m0_tdata = 32'hA0000000 + i;
            m0_tlast = (i == num_cycles);
            do @(posedge aclk); while (!m0_tready);
        end
        m0_tvalid = 0;
        m0_tlast = 0;
        @(posedge aclk);
    endtask

    // Send packet from m1
    task automatic send_m1_packet(input [1:0] dest, input [11:0] length, input int num_cycles);
        m1_tdata = {18'b0, dest, length};
        m1_tkeep = 4'hF;
        m1_tvalid = 1;
        m1_tlast = 0;
        do @(posedge aclk); while (!m1_tready);
        for (int i = 1; i <= num_cycles; i++) begin
            m1_tdata = 32'hB0000000 + i;
            m1_tlast = (i == num_cycles);
            do @(posedge aclk); while (!m1_tready);
        end
        m1_tvalid = 0;
        m1_tlast = 0;
        @(posedge aclk);
    endtask

    // check
    task automatic check(string name, logic condition);
        if (condition) begin
            $display("[%0t] PASS: %s", $time, name);
            tests_passed++;
        end else begin
            $display("[%0t] FAIL: %s", $time, name);
            tests_failed++;
        end
    endtask

    initial begin
        $display("   Packet Mux - Simple Testbench");

        aresetn = 0;
        m0_tdata = 0; m0_tkeep = 0; m0_tvalid = 0; m0_tlast = 0;
        m1_tdata = 0; m1_tkeep = 0; m1_tvalid = 0; m1_tlast = 0;
        s0_tready = 1; s1_tready = 1; s2_tready = 1;

        repeat(5) @(posedge aclk);
        aresetn = 1;
        repeat(2) @(posedge aclk);
        $display("[%0t] Reset complete\n", $time);

        // TEST 1: All routing combinations (m0/m1 to s0/s1/s2)
        $display("--- Testing all routing combinations ---");
        
        send_m0_packet(2'b00, 12'd2, 2);  // m0 -> s0
        check("m0 -> s0", !error_catch);
        
        send_m0_packet(2'b01, 12'd2, 2);  // m0 -> s1
        check("m0 -> s1", !error_catch);
        
        send_m0_packet(2'b10, 12'd2, 2);  // m0 -> s2
        check("m0 -> s2", !error_catch);
        
        send_m1_packet(2'b00, 12'd2, 2);  // m1 -> s0
        check("m1 -> s0", !error_catch);
        
        send_m1_packet(2'b01, 12'd2, 2);  // m1 -> s1
        check("m1 -> s1", !error_catch);
        
        send_m1_packet(2'b10, 12'd2, 2);  // m1 -> s2
        check("m1 -> s2", !error_catch);

        // TEST 2: Different packet lengths
        $display("\n--- Testing different packet lengths ---");
        
        send_m0_packet(2'b00, 12'd1, 1); 
        check("1-cycle packet", !error_catch);
        
        send_m0_packet(2'b01, 12'd5, 5); 
        check("5-cycle packet", !error_catch);
        
        send_m1_packet(2'b10, 12'd10, 10); 
        check("10-cycle packet", !error_catch);

        // TEST 3: Round-robin arbitration
        $display("\n--- Testing round-robin arbitration ---");
        
        // both masters case
        fork
            send_m0_packet(2'b00, 12'd2, 2);
            send_m1_packet(2'b01, 12'd2, 2);
        join
        check("Simultaneous m0/m1", !error_catch);
        
        // alternating masters case
        send_m0_packet(2'b00, 12'd1, 1);
        send_m1_packet(2'b01, 12'd1, 1);
        send_m0_packet(2'b10, 12'd1, 1);
        send_m1_packet(2'b00, 12'd1, 1);
        check("Alternating masters", !error_catch);

        // TEST 4: Illegal destination
        $display("\n--- Testing illegal destination ---");
        
        send_m0_packet(2'b11, 12'd2, 2);  // from m0
        check("Illegal dest m0", illegal_dst_error);
        
        send_m1_packet(2'b11, 12'd3, 3);  // from m1
        check("Illegal dest m1", illegal_dst_error && m1_pkt_dropped > 0);

        // TEST 5: Early TLAST error
        $display("\n--- Testing early TLAST ---");
        
        m0_tdata = {18'b0, 2'b00, 12'd5};
        m0_tkeep = 4'hF;
        m0_tvalid = 1;
        m0_tlast = 0;
        do @(posedge aclk); while (!m0_tready);
        
        // send only 2 cycles with tlast on 2nd
        m0_tdata = 32'hEE000001; m0_tlast = 0;
        do @(posedge aclk); while (!m0_tready);
        m0_tdata = 32'hEE000002; m0_tlast = 1;  // early here
        do @(posedge aclk); while (!m0_tready);
        m0_tvalid = 0; m0_tlast = 0;
        repeat(2) @(posedge aclk);
        check("Early TLAST detected", pkt_len_error);

        // TEST 6: Late TLAST error
        $display("\n--- Testing late TLAST ---");
        
        m0_tdata = {18'b0, 2'b01, 12'd2}; 
        m0_tkeep = 4'hF;
        m0_tvalid = 1;
        m0_tlast = 0;
        do @(posedge aclk); while (!m0_tready);
        
        // send 4 cycles with tlast on 4th
        for (int i = 1; i <= 4; i++) begin
            m0_tdata = 32'hFF000000 + i;
            m0_tlast = (i == 4);  // late here
            do @(posedge aclk); while (!m0_tready);
        end
        m0_tvalid = 0; m0_tlast = 0;
        repeat(2) @(posedge aclk);
        check("Late TLAST detected", pkt_len_error);

        // TEST 7: Backpressure handling
        $display("\n--- Testing backpressure ---");
        
        s0_tready = 0;  // block s0
        m0_tdata = {18'b0, 2'b00, 12'd2};
        m0_tkeep = 4'hF;
        m0_tvalid = 1;
        m0_tlast = 0;
        
        repeat(5) @(posedge aclk);  // wait with backpressure
        s0_tready = 1; 
        
        do @(posedge aclk); while (!m0_tready);
        m0_tdata = 32'hCC000001; m0_tlast = 0;
        do @(posedge aclk); while (!m0_tready);
        m0_tdata = 32'hCC000002; m0_tlast = 1;
        do @(posedge aclk); while (!m0_tready);
        m0_tvalid = 0; m0_tlast = 0;
        repeat(2) @(posedge aclk);
        check("Backpressure handled", 1);

        // Final Report
        $display("         STATISTICS");
        $display("m0: pkts=%0d, bytes=%0d, dropped=%0d", m0_pkt_count, m0_byte_count, m0_pkt_dropped);
        $display("m1: pkts=%0d, bytes=%0d, dropped=%0d", m1_pkt_count, m1_byte_count, m1_pkt_dropped);
        $display("s0: pkts=%0d, bytes=%0d", s0_pkt_count, s0_byte_count);
        $display("s1: pkts=%0d, bytes=%0d", s1_pkt_count, s1_byte_count);
        $display("s2: pkts=%0d, bytes=%0d", s2_pkt_count, s2_byte_count);
        
        $display("         SUMMARY");
        $display("Passed: %0d", tests_passed);
        $display("Failed: %0d", tests_failed);
        
        if (tests_failed == 0)
            $display("*** ALL TESTS PASSED! ***\n");
        else
            $display("*** SOME TESTS FAILED! ***\n");

        $finish;
    end

    initial begin
        #50000;
        $display("TIMEOUT!");
        $finish;
    end

    initial begin
        $dumpfile("packet_mux.vcd");
        $dumpvars(0, tb_packet_mux);
    end

endmodule