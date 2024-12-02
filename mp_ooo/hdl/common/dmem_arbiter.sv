module dmem_arbiter
(
    input   logic               clk,
    input   logic               rst,
    input   logic               backend_flush,

    ldq_dmem_itf.cache          load,
    stb_dmem_itf.cache          store,
    dmem_itf.cpu                cache
);

    logic                   dmem_valid;
    logic                   dmem_pending;
    logic                   pending_store;
    logic                   dmem_busy;
    logic                   dmem_flushed;

    assign load.ready = ~dmem_busy && ~dmem_flushed && ~store.valid;
    assign store.ready = ~dmem_busy && ~dmem_flushed;

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
        unique case ({load.valid, store.valid})
            2'b10: begin
                cache.addr = load.addr;
            end
            2'b01: begin
                cache.addr = store.addr;
            end
            2'b11: begin
                cache.addr = store.addr;
            end
            default: begin
                cache.addr = 'x;
            end
        endcase
    end

    assign load.resp = cache.resp && dmem_pending && ~pending_store && ~dmem_flushed;

endmodule
