module rat
import cpu_params::*;
import rat_types::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               backend_flush,
    input   logic   [PRF_IDX-1:0] rrf_mem[ARF_DEPTH],

    id_rat_itf.rat              from_id,
    cdb_itf.rat                 cdb[CDB_WIDTH]
);

    logic       [PRF_IDX:0]     mem         [ARF_DEPTH];    // msb for valid
    cdb_rat_t                   cdb_local   [CDB_WIDTH];

    generate
        for( genvar i = 0; i < CDB_WIDTH; i++ ) begin
            assign cdb_local[i].rd_arch = cdb[i].rd_arch;
            assign cdb_local[i].rd_phy = cdb[i].rd_phy;
            assign cdb_local[i].valid = cdb[i].valid;
        end
    endgenerate

    always_ff @( posedge clk ) begin
        if( rst ) begin
            for( int i = 0; i < ARF_DEPTH; i++ ) begin
                mem[i][PRF_IDX] <= 1'b1;
                mem[i][PRF_IDX-1:0] <= {1'b0, ARF_IDX'(i)};
            end
        end else if( backend_flush ) begin
            for( int i = 0; i < ARF_DEPTH; i++ ) begin
                mem[i][PRF_IDX] <= 1'b1;
                mem[i][PRF_IDX-1:0] <= rrf_mem[i];
            end
        end else begin
            for( int i = 0; i < CDB_WIDTH; i++ ) begin
                if( cdb_local[i].valid && (mem[cdb_local[i].rd_arch][PRF_IDX-1:0] == cdb_local[i].rd_phy) )
                    mem[cdb_local[i].rd_arch][PRF_IDX] <= 1'b1;
            end
            for (int i = 0; i < ID_WIDTH; i++) begin
                if( from_id.write_en[i] ) begin
                    mem[from_id.rd_arch[i]][PRF_IDX] <= 1'b0;
                    mem[from_id.rd_arch[i]][PRF_IDX-1:0] <= from_id.rd_phy[i];
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < ID_WIDTH; i++) begin
            from_id.rs1_phy[i] = mem[from_id.rs1_arch[i]][PRF_IDX-1:0];
            from_id.rs2_phy[i] = mem[from_id.rs2_arch[i]][PRF_IDX-1:0];
            from_id.rs1_valid[i] = mem[from_id.rs1_arch[i]][PRF_IDX];
            from_id.rs2_valid[i] = mem[from_id.rs2_arch[i]][PRF_IDX];

            // transparent RAT
            for( int j = 0; j < CDB_WIDTH; j++ ) begin
                if( cdb_local[j].valid ) begin
                    if ( cdb_local[j].rd_phy==from_id.rs1_phy[i] ) from_id.rs1_valid[i] = 1'b1;
                    if ( cdb_local[j].rd_phy==from_id.rs2_phy[i] ) from_id.rs2_valid[i] = 1'b1;
                end
            end

            // handle r0
            if( from_id.rs1_arch[i] == '0 ) begin
                from_id.rs1_phy[i]   = '0;
                from_id.rs1_valid[i] = 1'b1;
            end
            if( from_id.rs2_arch[i] == '0 ) begin
                from_id.rs2_phy[i]   = '0;
                from_id.rs2_valid[i] = 1'b1;
            end
        end
    end

endmodule
