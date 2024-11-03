dependency_test.s:
.align 4
.section .text
.globl _start
.globl _start
    # This program consists of small snippets
    # containing RAW, WAW, and WAR hazards

    # This test is NOT exhaustive
_start:

# initialize
li x1,  1
li x2,  2
li x3,  3

nop

mul x3, x1, x2
mul x2, x2, x2
mul x1, x3, x2

halt:
    slti x0, x0, -256
