module rat
import cpu_params::*;
(
    input   logic               clk,
    input   logic               rst,

    id_rat_itf.rat              from_id,
    cdb_itf.rat                 cdb[CDB_WIDTH]
);

    logic   [PRF_IDX:0]         mem [ARF_DEPTH];    // msb for valid

    always_ff @( posedge clk ) begin
        if( rst ) begin
            for( int i = 0; i < ARF_DEPTH; i++ ) begin
                mem[i][PRF_IDX] <= '1;
                mem[i][PRF_IDX-1:0] <= ARF_DEPTH'(unsigned(i));
            end
        end else begin
            if( from_id.write_en ) begin
                mem[i][PRF_IDX] <= '0;
                mem[from_id.write_arch][PRF_IDX-1:0] <= from_id.write_phy;
            end
            for( int i = 0; i < CDB_WIDTH; i++ ) begin
                if( cdb[i].valid && (mem[cdb[i].rd_arch][PRF_IDX-1:0] == cdb[i].rd_phy) )
                    mem[cdb[i].rd_arch][PRF_IDX] <= '1;
            end
        end
    end

    always_comb begin
        from_id.read_phy = mem[from_id.read_arch];
        // transparent RAT
        for( int i = 0; i < CDB_WIDTH; i++ ) begin
            if( cdb[i].valid && (mem[cdb[i].rd_arch][PRF_IDX-1:0] == cdb[i].rd_phy) && (cdb[i].rd_arch==id_rat_itf.read_arch) ) 
                from_id.read_phy[PRF_IDX] = '1;
        end
    end


endmodule
