package icache_types;

    typedef struct packed {
        logic   [3:0]   rmask;
        logic   [4:0]   offset;
        logic   [3:0]   set;
        logic   [22:0]  tag;
    } icache_stage_reg_t;

    typedef enum logic [1:0] {
        PASS_THRU       = 2'b00, // Any other states where miss does not happen
        ALLOCATE        = 2'b01, // Allocate new cache line
        ALLOCATE_STALL  = 2'b10  // One additional stall after allocate
    } icache_ctrl_fsm_state_t;

endpackage
