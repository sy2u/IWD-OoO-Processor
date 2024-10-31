module plru_update #(
            parameter               NUM_WAYS    = 4,
            parameter               PLRU_BITS   = 3,
            parameter               WAY_BITS    = 2
)(
    input   logic   [PLRU_BITS-1:0] current_plru,
    output  logic   [PLRU_BITS-1:0] next_plru,

    input   logic   [WAY_BITS-1:0]  hit_way,
    output  logic   [WAY_BITS-1:0]  replace_way
);

    // Output replace_way, the logic here could be a bit confusing, but it's just walking the PLRU tree
    always_comb begin
        replace_way = '0;
        for (int i = 0; i < WAY_BITS; i++) begin
            if (current_plru[replace_way]) begin
                replace_way = WAY_BITS'(replace_way * 2 + 1);
            end else begin
                replace_way = WAY_BITS'(replace_way * 2 + 2);
            end
        end
        replace_way = WAY_BITS'(replace_way + 1);
    end

    // Output next_plru
    logic   [WAY_BITS:0]  visit_bit;
    always_comb begin
        next_plru = current_plru;
        visit_bit = (WAY_BITS+1)'(hit_way + (WAY_BITS+1)'(NUM_WAYS - 1));
        for (int i = 0; i < WAY_BITS; i++) begin
            if (visit_bit[0]) begin
                visit_bit = (WAY_BITS+1)'((visit_bit - (WAY_BITS+1)'(1)) / (WAY_BITS+1)'(2));
                next_plru[visit_bit[WAY_BITS-1:0]] = 1'b0;
            end else begin
                visit_bit = (WAY_BITS+1)'((visit_bit - (WAY_BITS+1)'(1)) / (WAY_BITS+1)'(2));
                next_plru[visit_bit[WAY_BITS-1:0]] = 1'b1;
            end
        end
    end

endmodule
