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
            if( from_rob.valid ) 
                mem[from_rob.rd_arch] <= from_rob.rd_phy;
        end
    end
    always_comb begin
        to_fl.valid = '0;
        to_fl.stale_idx = 'x;
        if( from_rob.valid ) begin
            to_fl.valid = '1;
            to_fl.stale_idx = mem[from_rob.rd_arch];
        end
    end

endmodule
