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

    logic       [PRF_IDX:0]     mem [ARF_DEPTH];    // msb for valid
    cdb_rat_t                   cdb_local[CDB_WIDTH];

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
                mem[i][PRF_IDX] <= '1;
                mem[i][PRF_IDX-1:0] <= {1'b0, ARF_IDX'(i)};
            end
        end else if( backend_flush ) begin
            for( int i = 0; i < ARF_DEPTH; i++ ) begin
                mem[i][PRF_IDX] <= '1;
                mem[i][PRF_IDX-1:0] <= rrf_mem[i];
            end
        end else begin
            for( int i = 0; i < CDB_WIDTH; i++ ) begin
                if( cdb_local[i].valid && (mem[cdb_local[i].rd_arch][PRF_IDX-1:0] == cdb_local[i].rd_phy) )
                    mem[cdb_local[i].rd_arch][PRF_IDX] <= '1;
            end
            if( from_id.write_en ) begin
                mem[from_id.rd_arch][PRF_IDX] <= '0;
                mem[from_id.rd_arch][PRF_IDX-1:0] <= from_id.rd_phy;
            end
        end
    end

    always_comb begin
        from_id.rs1_phy = mem[from_id.rs1_arch][PRF_IDX-1:0];
        from_id.rs2_phy = mem[from_id.rs2_arch][PRF_IDX-1:0];
        from_id.rs1_valid = mem[from_id.rs1_arch][PRF_IDX];
        from_id.rs2_valid = mem[from_id.rs2_arch][PRF_IDX];

        // transparent RAT
        for( int i = 0; i < CDB_WIDTH; i++ ) begin
            if( cdb_local[i].valid && (mem[cdb_local[i].rd_arch][PRF_IDX-1:0] == cdb_local[i].rd_phy) ) begin
                if ( cdb_local[i].rd_arch==from_id.rs1_arch ) from_id.rs1_valid = '1;
                if ( cdb_local[i].rd_arch==from_id.rs2_arch ) from_id.rs2_valid = '1;
            end
        end

        // handle r0
        if( from_id.rs1_arch == '0 ) begin
            from_id.rs1_phy   = '0;
            from_id.rs1_valid = '1;
        end
        if( from_id.rs2_arch == '0 ) begin
            from_id.rs2_phy   = '0;
            from_id.rs2_valid = '1;
        end
    end

endmodule
