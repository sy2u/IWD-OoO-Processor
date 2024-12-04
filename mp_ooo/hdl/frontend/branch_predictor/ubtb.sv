module ubtb
import cpu_params::*;
import uop_types::*;
(
    input   logic                           clk,
    input   logic                           rst,

    cb_bp_itf.bp                            from_cb,

    input   logic [IF_WIDTH-1:0]            predict_taken_gshare,
    input   logic [31:0]                    blk_pc,
    output  logic [IF_WIDTH-1:0]  [31:0]    predict_target,
    output  logic [IF_WIDTH-1:0]	        predict_taken
);
    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;
    
    typedef struct packed {
        logic                       valid;
        logic   [31:0]              target;
        logic   [UBTB_TAG_IDX-1:0]  tag;
    } ubtb_entry_t;

    typedef enum logic [2:0] {  
        INSERT          = 3'b001,
        UPDATE          = 3'b010,
        OVERWRITE       = 3'b100
    } ubtb_update_t;

    ubtb_entry_t            br_ubtb    [UBTB_DEPTH];
    ubtb_update_t           br_ubtb_update;
    logic [UBTB_IDX-1:0]    br_update_idx;
    logic [UBTB_IDX-1:0]    br_insert_idx;
    logic [UBTB_IDX-1:0]    br_ubtb_head;

    always_ff @(posedge clk) begin
        if (rst) begin
            br_ubtb_head <= '0;
            for (int i = 0; i < UBTB_DEPTH; i++) begin
                br_ubtb[i].valid    <= '0;
            end
        end else if (from_cb.update_en && from_cb.branch_taken && ~from_cb.fu_opcode[3]) begin
            unique case (br_ubtb_update)
                INSERT: begin
                    br_ubtb[br_insert_idx].valid    <= '1;
                    br_ubtb[br_insert_idx].tag      <= from_cb.pc[UBTB_TAG_IDX+1:2];
                    br_ubtb[br_insert_idx].target   <= from_cb.target_address;
                end
                UPDATE: begin
                    br_ubtb[br_update_idx].tag      <= from_cb.pc[UBTB_TAG_IDX+1:2];
                    br_ubtb[br_update_idx].target   <= from_cb.target_address;
                end
                OVERWRITE: begin
                    br_ubtb[br_ubtb_head].tag       <= from_cb.pc[UBTB_TAG_IDX+1:2];
                    br_ubtb[br_ubtb_head].target    <= from_cb.target_address;
                    br_ubtb_head <= br_ubtb_head + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    always_comb begin
        br_ubtb_update = OVERWRITE;
        br_update_idx = 'x;
        br_insert_idx = 'x;

        for (int unsigned i = 0; i < UBTB_DEPTH; i++) begin
            if (~from_cb.fu_opcode[3]) begin
                if (!br_ubtb[i].valid) begin
                    br_ubtb_update = INSERT;
                    br_insert_idx = (UBTB_IDX)'(i);
                end else if (br_ubtb[i].tag == from_cb.pc[UBTB_TAG_IDX+1:2]) begin
                    br_ubtb_update = UPDATE;
                    br_update_idx = (UBTB_IDX)'(i);
                end
            end
        end
    end

    ubtb_entry_t            j_ubtb     [UBTB_DEPTH];
    ubtb_update_t           j_ubtb_update;
    logic [UBTB_IDX-1:0]    j_update_idx;
    logic [UBTB_IDX-1:0]    j_insert_idx;
    logic [UBTB_IDX-1:0]    j_ubtb_head;

    always_ff @(posedge clk) begin
        if (rst) begin
            j_ubtb_head  <= '0;
            for (int i = 0; i < UBTB_DEPTH; i++) begin
                j_ubtb[i].valid     <= '0;
            end
        end else if (from_cb.update_en && from_cb.branch_taken && from_cb.fu_opcode[3]) begin
            unique case (j_ubtb_update)
                INSERT: begin
                    j_ubtb[j_insert_idx].valid    <= '1;
                    j_ubtb[j_insert_idx].tag      <= from_cb.pc[UBTB_TAG_IDX+1:2];
                    j_ubtb[j_insert_idx].target   <= from_cb.target_address;
                end
                UPDATE: begin
                    j_ubtb[j_update_idx].tag      <= from_cb.pc[UBTB_TAG_IDX+1:2];
                    j_ubtb[j_update_idx].target   <= from_cb.target_address;
                end
                OVERWRITE: begin
                    j_ubtb[j_ubtb_head].tag       <= from_cb.pc[UBTB_TAG_IDX+1:2];
                    j_ubtb[j_ubtb_head].target    <= from_cb.target_address;
                    j_ubtb_head <= j_ubtb_head + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

    always_comb begin
        j_ubtb_update = OVERWRITE;
        j_update_idx = 'x;
        j_insert_idx = 'x;

        for (int unsigned i = 0; i < UBTB_DEPTH; i++) begin
            if (from_cb.fu_opcode[3]) begin
                if (!j_ubtb[i].valid) begin
                    j_ubtb_update = INSERT;
                    j_insert_idx = (UBTB_IDX)'(i);
                end else if(j_ubtb[i].tag == from_cb.pc[UBTB_TAG_IDX+1:2]) begin
                    j_ubtb_update = UPDATE;
                    j_update_idx = (UBTB_IDX)'(i);
                end
            end
        end
    end

    logic   [IF_WIDTH-1:0]  [31:0]  pc_in;
    generate for (genvar w = 0; w < IF_WIDTH; w++) begin
        always_comb begin
	        predict_taken[w] = 1'b0;
            pc_in[w] = blk_pc + unsigned'(w) * 4;
            predict_target[w] = blk_pc + unsigned'(w) * 4 + 4;
            for (int i = 0; i < UBTB_DEPTH; i++) begin
                if (predict_taken_gshare[w] && br_ubtb[i].valid && (br_ubtb[i].tag == pc_in[w][UBTB_TAG_IDX+1:2])) begin
                    predict_target[w] = br_ubtb[i].target;
		            predict_taken[w]  = 1'b1;
                    break;
                end
                // prioritize jump over branch
                if (j_ubtb[i].valid && (j_ubtb[i].tag == pc_in[w][UBTB_TAG_IDX+1:2])) begin
                    predict_target[w] = j_ubtb[i].target;
		            predict_taken[w] = 1'b1;
                    break;
                end
            end
        end
    end endgenerate

endmodule
