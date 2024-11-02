module rat
import cpu_params::*;
import rat_types::*;
(
    input   logic               clk,
    input   logic               rst,

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
        end else begin
            if( from_id.write_en ) begin
                mem[from_id.write_arch][PRF_IDX] <= '0;
                mem[from_id.write_arch][PRF_IDX-1:0] <= from_id.write_phy;
            end
            for( int i = 0; i < CDB_WIDTH; i++ ) begin
                if( cdb_local[i].valid && (mem[cdb_local[i].rd_arch][PRF_IDX-1:0] == cdb_local[i].rd_phy) )
                    mem[cdb_local[i].rd_arch][PRF_IDX] <= '1;
            end
        end
    end

    always_comb begin
        from_id.read_phy[0] = mem[from_id.read_arch[0]][PRF_IDX-1:0];
        from_id.read_phy[1] = mem[from_id.read_arch[1]][PRF_IDX-1:0];
        from_id.read_valid[0] = mem[from_id.read_arch[0]][PRF_IDX];
        from_id.read_valid[1] = mem[from_id.read_arch[1]][PRF_IDX];
        // transparent RAT
        for( int i = 0; i < CDB_WIDTH; i++ ) begin
            if( cdb_local[i].valid && (mem[cdb_local[i].rd_arch][PRF_IDX-1:0] == cdb_local[i].rd_phy) ) begin
                if      ( cdb_local[i].rd_arch==from_id.read_arch[0] ) from_id.read_valid[0] = '1;
                else if ( cdb_local[i].rd_arch==from_id.read_arch[1] ) from_id.read_valid[1] = '1;
            end
        end
        // handle r0
        if( from_id.read_arch[0] == '0 ) begin
            from_id.read_phy[0]   = '0;
            from_id.read_valid[0] = '1;
        end
        if( from_id.read_arch[1] == '0 ) begin
            from_id.read_phy[1]   = '0;
            from_id.read_valid[1] = '1;
        end
    end


endmodule
