dependency_test.s:
.align 4
.section .text
.globl _start
.globl _start
    # This program consists of small snippets
    # containing RAW, WAW, and WAR hazards

    # This test is NOT exhaustive
_start:
loop:
    beq x0, x0, loop
halt:
    slti x0, x0, -256

