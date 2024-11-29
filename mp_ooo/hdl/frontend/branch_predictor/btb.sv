module btb
import cpu_params::*;
import uop_types::*;
(
    input   logic                           clk,
    input   logic                           rst,

    cb_bp_itf.bp                            from_cb,

    input   logic [IF_WIDTH-1:0]            predict_taken_gshare,
    input   logic [31:0]                    pc,
    output  logic [IF_WIDTH-1:0]  [31:0]    predict_target,
    output  logic [IF_WIDTH-1:0]	    predict_taken
);
    localparam  unsigned    IF_BLK_SIZE = IF_WIDTH * 4;
    
    typedef struct packed {
        logic                   valid;
        logic   [31:0]          target_address;
        logic   [31:0]          pc;
    } btb_entry_t;

    btb_entry_t     br_btb[BTB_DEPTH];
    btb_entry_t     j_btb[BTB_DEPTH];

    // counter: no insert, no update 
    // insert: insert an invalid slot 
    // update: update the target pc
    logic br_update;
    logic br_insert;
    logic [BTB_IDX-1:0] br_update_index;
    logic [BTB_IDX-1:0] br_insert_index;
    logic [BTB_IDX-1:0] br_counter;

    logic j_update;
    logic j_insert;
    logic [BTB_IDX-1:0] j_update_index;
    logic [BTB_IDX-1:0] j_insert_index;
    logic [BTB_IDX-1:0] j_counter;

    logic   [IF_WIDTH-1:0]  [31:0]  pc_in;

    always_ff @(posedge clk) begin
        if (rst) begin
            br_counter <= '0;
            j_counter  <= '0;
            for (int i = 0; i < BTB_DEPTH; i++) begin
                br_btb[i]  <= '0;
                j_btb[i]   <= '0;
            end
        end else begin
            if (from_cb.update_en && from_cb.branch_taken) begin
                if (from_cb.fu_opcode == BR_JAL || from_cb.fu_opcode == BR_JALR) begin
                    if (j_update) begin
                        j_btb[j_update_index].pc    <= from_cb.pc;
                        j_btb[j_update_index].target_address <= from_cb.target_address;
                    end else if (j_insert) begin
                        j_btb[j_insert_index].valid          <= '1;
                        j_btb[j_insert_index].pc             <= from_cb.pc;
                        j_btb[j_insert_index].target_address <= from_cb.target_address;
                    end else begin
                        j_btb[j_counter].pc                 <= from_cb.pc;
                        j_btb[j_counter].target_address     <= from_cb.target_address;
                        j_counter <= j_counter + 1'b1;
                    end
                end else begin
                    if (br_update) begin
                        br_btb[br_update_index].pc             <= from_cb.pc;
                        br_btb[br_update_index].target_address <= from_cb.target_address;
                    end else if (br_insert) begin
                        br_btb[br_insert_index].valid          <= '1;
                        br_btb[br_insert_index].pc             <= from_cb.pc;
                        br_btb[br_insert_index].target_address <= from_cb.target_address;
                    end else begin
                        br_btb[br_counter].pc             <= from_cb.pc;
                        br_btb[br_counter].target_address <= from_cb.target_address;
                        br_counter <= br_counter + 1'b1;
                    end
                end
            end
        end
    end

    always_comb begin
        br_update = '0;
        br_insert = '0;
        br_update_index = '0;
        br_insert_index = '0;
        j_update = '0;
        j_insert = '0;
        j_update_index = '0;
        j_insert_index = '0;

        for (int unsigned i = 0; i < BTB_DEPTH; i++) begin
            if (from_cb.fu_opcode == BR_JAL || from_cb.fu_opcode == BR_JALR) begin
                if (j_btb[i].valid && (j_btb[i].pc == from_cb.pc)) begin
                    j_update = '1;
                    j_update_index = (BTB_IDX)'(i);
                end
                if (!j_btb[i].valid) begin
                    j_insert = '1;
                    j_insert_index = (BTB_IDX)'(i);
                end
            end else begin
                if (br_btb[i].valid && (br_btb[i].pc == from_cb.pc)) begin
                    br_update = '1;
                    br_update_index = (BTB_IDX)'(i);
                end
                if (!br_btb[i].valid) begin
                    br_insert = '1;
                    br_insert_index = (BTB_IDX)'(i);
                end
            end
        end
    end

    generate for (genvar k = 0; k < IF_WIDTH; k++) begin
        always_comb begin
	    predict_taken[k] = 1'b0;
            pc_in[k] = (pc & ~(unsigned'(IF_BLK_SIZE - 1))) + unsigned'(k) * 4;
            predict_target[k] = (pc & ~(unsigned'(IF_BLK_SIZE - 1))) + unsigned'(k) * 4 + 4;
            for (int i = 0; i < BTB_DEPTH; i++) begin
                if (predict_taken_gshare[k] && br_btb[i].valid && (br_btb[i].pc == pc_in[k])) begin
                    predict_target[k] = br_btb[i].target_address;
		    predict_taken[k]  = 1'b1;
                    break;
                end
                if (j_btb[i].valid && (j_btb[i].pc == pc_in[k])) begin
                    predict_target[k] = j_btb[i].target_address;
		    predict_taken[k] = 1'b1;
                    break;
                end
            end
        end
    end endgenerate
endmodule
