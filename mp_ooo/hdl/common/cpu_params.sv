package cpu_params;

    localparam  unsigned    IF_WIDTH    = 1;

    localparam  unsigned    ID_WIDTH    = 1;

    localparam  unsigned    ROB_DEPTH   = 32;
    localparam  unsigned    ROB_IDX     = $clog2(ROB_DEPTH);

    localparam  unsigned    PRF_DEPTH   = 64;
    localparam  unsigned    PRF_IDX     = $clog2(PRF_DEPTH);

    // Do not change this
    localparam  unsigned    ARF_DEPTH   = 32;
    localparam  unsigned    ARF_IDX     = $clog2(ARF_DEPTH);


endpackage