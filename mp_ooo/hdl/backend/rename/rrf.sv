module rrf
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    rob_rrf_itf.rrf             from_rob,
    rrf_fl_itf.rrf              to_fl
);

    logic     [PRF_IDX-1:0]     mem [ARF_DEPTH];

    always_ff @( posedge clk ) begin
        if( rst ) begin 
            for( int i = 0; i < ARF_DEPTH; i++ ) begin
                mem[i] <= {1'b0, ARF_IDX'(i)};  // sync with rat
            end
        end else begin
            for (int i = 0; i < ID_WIDTH; i++) begin
                if (from_rob.valid[i] && (from_rob.rd_arch[i]!='0)) begin
                    mem[from_rob.rd_arch[i]] <= from_rob.rd_phy[i];
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < ID_WIDTH; i++) begin
            to_fl.valid[i] = '0;
            to_fl.stale_idx[i] = 'x;
            if( from_rob.valid[i] && (from_rob.rd_arch[i] != '0) ) begin
                to_fl.valid[i] = '1;
                to_fl.stale_idx[i] = mem[from_rob.rd_arch[i]];
            end
        end
    end

endmodule
