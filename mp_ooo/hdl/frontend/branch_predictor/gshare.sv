module gshare
import cpu_params::*;
(
    input   logic                   clk,
    input   logic                   rst,

    cb_bp_itf.bp                    from_cb,
    input   logic [31:0]            blk_pc,
    output  logic [IF_WIDTH-1:0]    predict_taken
);
    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;
    
    logic   [PHT_IDX-1:0] ghr;
    logic   [1:0] pht[PHT_DEPTH];

    always_ff @(posedge clk) begin
        if (rst) begin 
            ghr <= '0;
            for (int i = 0; i < PHT_DEPTH; i++) begin
                pht[i] <= 2'b01;
            end
        end else begin 
            if (from_cb.update_en) begin 
                ghr <= {ghr[PHT_IDX-2:0], from_cb.branch_taken};
                if (from_cb.branch_taken) begin 
                    pht[ghr ^ from_cb.pc[PHT_IDX+1:2]] <= (pht[ghr ^ from_cb.pc[PHT_IDX+1:2]] == 2'b11) ? 2'b11 : pht[ghr ^ from_cb.pc[PHT_IDX+1:2]] + 2'd1;
                end else begin 
                    pht[ghr ^ from_cb.pc[PHT_IDX+1:2]] <= (pht[ghr ^ from_cb.pc[PHT_IDX+1:2]] == 2'b00) ? 2'b00 : pht[ghr ^ from_cb.pc[PHT_IDX+1:2]] - 2'd1;
                end
            end
        end
    end

    logic   [IF_WIDTH-1:0]  [31:0]  pc_in;
    generate for (genvar i = 0; i < IF_WIDTH; i++) begin
        assign pc_in[i] = blk_pc + unsigned'(i) * 4;
        assign predict_taken[i] = pht[ghr ^ pc_in[i][PHT_IDX+1:2]] >= 2'b10;
    end endgenerate

endmodule
