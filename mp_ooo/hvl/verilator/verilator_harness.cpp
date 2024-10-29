#define TOPLEVEL top_tb

#include <csignal>
#include <iostream>
#include <stdint.h>
#include <stdlib.h>

#include "Vtop_tb.h"
#include <verilated.h>

#if VM_TRACE_FST
    #include <verilated_fst_c.h>
#else
    #include <verilated_vcd_c.h>
#endif

#define MAX_SIM_TIME 20000000

typedef Vtop_tb dut_t;

#if VM_TRACE_FST
    typedef VerilatedFstC trace_t;
#else
    typedef VerilatedVcdC trace_t;
#endif

dut_t* dut;
trace_t* m_trace;

vluint64_t sim_time = 0;

uint64_t clk_half_period = 0;
int64_t log_start_time = -1, log_end_time = -1;

VerilatedContext* contextp;

double sc_time_stamp() {
    return sim_time*clk_half_period;
}

void end(bool failed = false) {
    dut->final();

    if (m_trace != NULL) {
        m_trace->close();
    }

    delete dut;
    delete m_trace;

    contextp->statsPrintSummary();

    exit(failed ? EXIT_FAILURE : 0);
}

void tick(dut_t* dut) {
    if (m_trace != NULL) {
        if (sim_time * clk_half_period <= log_end_time && sim_time * clk_half_period >= log_start_time) {
            m_trace->dump(sim_time * clk_half_period);
        }
    }

    dut->clk ^= 1;
    dut->eval();
    sim_time++;
}

void wait(dut_t* dut, trace_t* m_trace, int cycles) {
    for (int i = 0; i < cycles * 2; i++) {
        tick(dut);
    }
}

int main(int argc, char** argv, char** env) {
    contextp = new VerilatedContext;

    if (argc < 4) {
        std::cerr << "ERR: Invalid argument count. This binary requires clock half period and logging checkpoints as inline arguments. \n";
        exit(EXIT_FAILURE);
    }

    try {
        clk_half_period = (uint64_t)std::stoi(argv[1]);
        log_start_time = (int64_t)std::stoi(argv[2]);
        log_end_time = (int64_t)std::stoi(argv[3]);
    } catch (const std::exception& e) {
        std::cerr << "ERR: Invalid command line arg" << std::endl;
        exit(EXIT_FAILURE);
    }

    if (log_start_time != -1 && log_end_time == -1) {
        log_end_time = MAX_SIM_TIME * clk_half_period;
    }

    if (log_end_time < log_start_time) {
        std::cerr << "ERR: Invalid logging bounds" << std::endl;
        exit(EXIT_FAILURE);
    }

    if (log_start_time != -1) {
        std::cout << "Logging traces from " << log_start_time << " to " << log_end_time << std::endl;
    }

    contextp->commandArgs(argc, argv);

    dut = new dut_t;

    Verilated::traceEverOn(true);
    if (log_start_time != -1) {

        #if VM_TRACE_FST
            m_trace = new VerilatedFstC;
        #else
            m_trace = new VerilatedVcdC;
        #endif

        dut->trace(m_trace, 5);\

        #if VM_TRACE_FST
            m_trace->open("waveform.fst");
        #else
            m_trace->open("waveform.vcd");
        #endif

    } else {
        m_trace = NULL;
    }

    dut->clk = 1;
    dut->rst = 1;

    wait(dut, m_trace, 2);

    dut->rst = 0;

    for (int i = 0; i < MAX_SIM_TIME; i++) {
        if (dut->halt) {
            if (dut->error)
                wait(dut, m_trace, 4);
            end(dut->error);
        }

        wait(dut, m_trace, 1);
    }

    end();
}
