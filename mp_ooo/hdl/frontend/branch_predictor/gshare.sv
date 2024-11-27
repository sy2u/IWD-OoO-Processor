module gshare
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    cb_bp_itf.bp                from_cb,
    input   logic               pc,
    output  logic               predict_taken
);
    logic   [GHR_DEPTH-1:0] ghr;
    logic   [BIMODAL_DEPTH-1:0] pht[PHT_DEPTH];


    always_ff @(posedge clk) begin
        if (rst) begin 
            ghr <= '0;
            for (int i = 0; i < PHT_DEPTH; i++) begin
                pht[i] <= 2'b01;
            end
        end else begin 
            if (from_cb.update_en) begin 
                ghr <= {ghr[GHR_DEPTH-2:0], from_cb.branch_taken};
                if (branch_taken) begin 
                    pht[ghr[PHT_IDX-1:0] ^ from_cb.pc[PHT_IDX+1:2]] <= (pht[ghr[PHT_IDX-1:0] ^ from_cb.pc[PHT_IDX+1:2]] == 2'b11) ? 2'b11 : pht[ghr[PHT_IDX-1:0] ^ from_cb.pc[PHT_IDX+1:2]] + 1;
                end else begin 
                    pht[ghr[PHT_IDX-1:0] ^ from_cb.pc[PHT_IDX+1:2]] <= (pht[ghr[PHT_IDX-1:0] ^ from_cb.pc[PHT_IDX+1:2]] == 2'b00) ? 2'b00 : pht[ghr[PHT_IDX-1:0] ^ from_cb.pc[PHT_IDX+1:2]] - 1;
                end
            end
        end    
    end

    assign predict_taken = pht[ghr[PHT_IDX-1:0] ^ pc[PHT_IDX+1:2]] >= 2'b10;
endmodule