#define TOPLEVEL top_tb

#include <csignal>
#include <iostream>
#include <sstream>
#include <stdint.h>
#include <stdlib.h>

#include "Vtop_tb.h"
#include <verilated.h>

#if VM_TRACE_FST
#include <verilated_fst_c.h>
typedef VerilatedFstC trace_t;
#else
#include <verilated_vcd_c.h>
typedef VerilatedVcdC trace_t;
#endif

typedef Vtop_tb dut_t;

dut_t* dut;
trace_t* m_trace;

uint64_t clk_half_period = 0;
uint64_t timeout = 0;
int64_t log_start_time = -1;
int64_t log_end_time = -1;

VerilatedContext* contextp;

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
        if (contextp->time() <= log_end_time && contextp->time() >= log_start_time) {
            m_trace->dump(contextp->time());
        }
    }

    contextp->timeInc(clk_half_period);
    dut->clk ^= 1;
    dut->eval();
}

void wait(dut_t* dut, trace_t* m_trace, int cycles) {
    for (int i = 0; i < cycles * 2; i++) {
        tick(dut);
    }
}

uint64_t get_int_plusarg(std::string arg) {
    std::string s(contextp->commandArgsPlusMatch(arg.c_str()));
    std::replace(s.begin(), s.end(), '=', ' ');
    std::stringstream ss(s);
    std::string p;
    uint64_t retval;
    ss >> p;
    ss >> retval;
    return retval;
}

uint64_t funny_stol(std::string s) {
    std::stringstream ss(s);
    uint64_t retval;
    ss >> retval;
    return retval;
}

int main(int argc, char** argv, char** env) {
    contextp = new VerilatedContext;

    if (argc < 3) {
        std::cerr << "ERR: Invalid argument count. This binary requires logging checkpoints as inline arguments. \n";
        exit(EXIT_FAILURE);
    }

    contextp->commandArgs(argc, argv);

    try {
        log_start_time = funny_stol(argv[1]);
        log_end_time = funny_stol(argv[2]);
        clk_half_period = get_int_plusarg("CLOCK_PERIOD_PS_ECE411") / 2;
        timeout = 2 * clk_half_period * get_int_plusarg("TIMEOUT_ECE411");
    } catch (const std::exception& e) {
        std::cerr << "ERR: Invalid command line arg" << std::endl;
        exit(EXIT_FAILURE);
    }

    if (log_start_time != -1 && log_end_time == -1) {
        log_end_time = timeout;
    }

    if (log_end_time < log_start_time) {
        std::cerr << "ERR: Invalid logging bounds" << std::endl;
        exit(EXIT_FAILURE);
    }

    if (log_start_time != -1) {
        std::cout << "TB: Logging traces from " << log_start_time << " to " << log_end_time << std::endl;
    }

    dut = new dut_t;

    Verilated::traceEverOn(true);
    if (log_start_time != -1) {

#if VM_TRACE_FST
        m_trace = new VerilatedFstC;
#else
        m_trace = new VerilatedVcdC;
#endif

        dut->trace(m_trace, 5);

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

    while (true) {
        if (dut->error) {
            wait(dut, m_trace, 5);
            end(true);
        }

        if (dut->halt) {
            end(dut->error);
        }

        if (contextp->time() >= timeout) {
            std::cout << "TB Error: Timed out" << std::endl;
            end(true);
        }

        wait(dut, m_trace, 1);
    }
}
