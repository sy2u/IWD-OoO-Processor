module dmem_arbiter
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,

    ldq_dmem_itf.cache          load,
    stb_dmem_itf.cache          store,
    dmem_itf.cpu                cache
);

    typedef enum logic [0:0] {
        LOAD        = 1'b0,
        STORE       = 1'b1
    } arbiter_priority_t;

    logic                   dmem_valid;
    logic                   dmem_pending;
    logic                   pending_store;
    logic                   dmem_busy;
    logic                   dmem_flushed;
    arbiter_priority_t      arbiter_priority;

    assign load.ready = (arbiter_priority == LOAD) ? ~dmem_busy && ~dmem_flushed : ~dmem_busy && ~dmem_flushed && ~store.valid;
    assign store.ready = (arbiter_priority == STORE) ?  ~dmem_busy && ~dmem_flushed : ~dmem_busy && ~dmem_flushed && ~load.valid;

    // Round robin arbiter
    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         arbiter_priority <= LOAD;
    //     end else if (load.valid && load.ready) begin
    //         arbiter_priority <= STORE;
    //     end else if (store.valid && store.ready) begin
    //         arbiter_priority <= LOAD;
    //     end
    // end

    // Cyclic arbiter
    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         arbiter_priority <= LOAD;
    //     end else if (arbiter_priority == LOAD) begin
    //         arbiter_priority <= STORE;
    //     end else if (arbiter_priority == STORE) begin
    //         arbiter_priority <= LOAD;
    //     end
    // end

    // Fix priority arbiter
    assign arbiter_priority = LOAD;
    // assign arbiter_priority = STORE;

    always_ff @(posedge clk) begin
        if (rst) begin
            dmem_pending <= '0;
        end else if ((load.valid && load.ready) || (store.valid && store.ready)) begin
            dmem_pending <= '1;
        end else if (cache.resp) begin
            dmem_pending <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pending_store <= '0;
        end else if (store.valid && store.ready) begin
            pending_store <= '1;
        end else if (cache.resp) begin
            pending_store <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            dmem_flushed <= '0;
        end else if (dmem_busy && backend_flush) begin
            dmem_flushed <= '1;
        end else if (cache.resp) begin
            dmem_flushed <= '0;
        end
    end

    assign dmem_busy = dmem_pending && ~cache.resp;

    assign cache.rmask = (load.valid && load.ready) ? load.rmask : '0;
    assign cache.wmask = (store.valid && store.ready) ? store.wmask : '0;
    assign cache.wdata = store.wdata;
    assign load.rdata = cache.rdata;

    always_comb begin
        if (load.valid && load.ready) begin
            cache.addr = load.addr;
        end else if (store.valid && store.ready) begin
            cache.addr = store.addr;
        end else begin
            cache.addr = 'x;
        end
    end

    assign load.resp = cache.resp && dmem_pending && ~pending_store && ~dmem_flushed;

endmodule
