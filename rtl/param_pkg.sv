package param_pkg;
    // globals
    parameter int DATA_WIDTH = 32;
    parameter int KEEP_WIDTH = DATA_WIDTH / 8;
    parameter int LEN_WIDTH = 12;
    parameter int COUNT_WIDTH = 32;
    
    //field constants
    localparam int SRC_BIT = 14;
    localparam int DST_MSB = 13;
    localparam int DST_LSB = 12;
    localparam int LEN_MSB = 11;
    localparam int LEN_LSB = 0;

    typedef enum logic [1:0] {
        DST_S0  =  2'b00,
        DST_S1  =  2'b01,
        DST_S2  =  2'b10,
        DST_ILL =  2'b11
    } dst_t;

    typedef enum logic [1:0] {
        ROUTER_IDLE,
        ROUTER_PROCESS,
        ROUTER_DATA
    } router_state_t;

    // rebuild unpacked control word for output
    typedef struct packed {
        logic                   source;
        dst_t                   dst;
        logic [LEN_WIDTH-1:0]   num_words;
    } ctrl_processed_t;

endpackage : param_pkg