module hit_detection
import dcache_types::*; #(
            parameter               TAG_IDX     = 23,
            parameter               NUM_WAYS    = 4,
            parameter               WAY_BITS    = 2
)
(
    input   logic   [TAG_IDX-1:0]   tag,
    input   logic   [TAG_IDX:0]     tag_arr_out[NUM_WAYS],
    input   logic   [0:0]           valid_arr_out[NUM_WAYS],
    output  logic                   hit,
    output  logic   [WAY_BITS-1:0]  hit_way
);


    always_comb begin
        hit = 1'b0;
        hit_way = 'x;

        for (int i = 0; i < NUM_WAYS; i++) begin
            if (tag_arr_out[i][22:0] == tag && valid_arr_out[i]) begin
                hit = 1'b1;
                hit_way = WAY_BITS'(unsigned'(i));
            end
        end
    end

endmodule