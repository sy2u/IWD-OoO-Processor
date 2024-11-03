//-----------------------------------------------------------------------------
// Title                 : random_tb
// Project               : ECE 411 mp_verif
//-----------------------------------------------------------------------------
// File                  : random_tb.sv
// Author                : ECE 411 Course Staff
//-----------------------------------------------------------------------------
// IMPORTANT: If you don't change the random seed, every time you do a `make run`
// you will run the /same/ random test. SystemVerilog calls this "random stability",
// and it's to ensure you can reproduce errors as you try to fix the DUT. Make sure
// to change the random seed or run more instructions if you want more extensive
// coverage.
//------------------------------------------------------------------------------
module random_tb 
import rv32i_types::*; #(
    parameter CHANNELS = 2
)
(
    mem_itf_w_mask.mem itf,
    input logic [31:0] reg_data[32]
);

    `include "../../hvl/vcs/randinst.svh"

    RandInst gen = new();

    // Do a bunch of LUIs to get useful register state.
    task init_register_state();
        for (int i = 0; i < 32; ++i) begin
            @(posedge itf.clk iff |itf.rmask[0]);
            itf.rdata[0] <= 'x;
            itf.resp[0] <= 1'b0;

            // stall the processor for 2 cycles
            // repeat (2) @(posedge itf.clk);

            gen.randomize() with {
                instr.j_type.opcode == op_b_lui;
                instr.j_type.rd == i[4:0];
            };

            // Your code here: package these memory interactions into a task.
            itf.rdata[0] <= gen.instr.word;
            itf.resp[0] <= 1'b1;

            // @(posedge itf.clk) itf.resp[0] = 1'b0; // Instruction memory never stalls for now.
        end
    endtask : init_register_state

    // Note that this memory model is not consistent! It ignores
    // writes and always reads out a random, valid instruction.
    task run_random_instrs();
        repeat (10000) begin
            @(posedge itf.clk iff |itf.rmask[0]);
            itf.rdata[0] <= 'x;
            itf.resp[0] <= 1'b0;

            // stall the processor for 2 cycles
            // repeat (2) @(posedge itf.clk);

            // Always read out a valid instruction.
            gen.update_regs(reg_data);
            gen.randomize();
            itf.rdata[0] <= gen.instr.word;
            itf.resp[0] <= 1'b1;

            // We have to insert 5 nops because otherwise
            // the testbench won't be able to read the correct regfile
            // to generate instruction that doesn't trap
            // repeat (5) begin
            //     @(posedge itf.clk iff |itf.rmask[0]);
            //     itf.rdata[0] <= 'x;
            //     itf.resp[0] <= 1'b0;
            //     repeat (2) @(posedge itf.clk);
            //     itf.rdata[0] <= 32'b0000000000000000000000000010011;
            //     itf.resp[0] <= 1'b1;
            // end
        end
    endtask : run_random_instrs

    // always_ff @(posedge itf.clk) begin
    //     if (|itf.rmask[1] || |itf.wmask[1]) begin
    //         itf.rdata[1] <= $urandom();
    //         itf.resp[1] <= 1'b1;
    //     end else begin
    //         itf.rdata[1] <= 'x;
    //         itf.resp[1] <= 1'b0;
    //     end
    // end

    always @(posedge itf.clk iff !itf.rst) begin
        if ($isunknown(itf.rmask[0]) || $isunknown(itf.wmask[0])) begin
            $error("Memory Error: mask containes 'x");
            itf.error <= 1'b1;
        end
        if ((|itf.rmask[0]) && (|itf.wmask[0])) begin
            $error("Memory Error: simultaneous memory read and write");
            itf.error <= 1'b1;
        end
        if ((|itf.rmask[0]) || (|itf.wmask[0])) begin
            if ($isunknown(itf.addr[0])) begin
                $error("Memory Error: address contained 'x");
                itf.error <= 1'b1;
            end
        end
        if ($isunknown(itf.rmask[1]) || $isunknown(itf.wmask[1])) begin
                $error("Memory Error: mask containes 'x");
                itf.error <= 1'b1;
            end
            if ((|itf.rmask[1]) && (|itf.wmask[1])) begin
                $error("Memory Error: simultaneous memory read and write");
                itf.error <= 1'b1;
            end
            if ((|itf.rmask[1]) || (|itf.wmask[1])) begin
                if ($isunknown(itf.addr[1])) begin
                    $error("Memory Error: address contained 'x");
                    itf.error <= 1'b1;
                end
                if (itf.addr[1][1:0] != 2'b00) begin
                    $error("Memory Error: address is not 32-bit aligned");
                    itf.error <= 1'b1;
                end
            end
    end

    // A single initial block ensures random stability.
    initial begin

        // Wait for reset.
        @(posedge itf.clk iff itf.rst == 1'b1);

        // Get some useful state into the processor by loading in a bunch of state.
        init_register_state();

        // Run!
        run_random_instrs();

        // Finish up
        $display("Random testbench finished!");
        $finish;
    end

endmodule : random_tb
