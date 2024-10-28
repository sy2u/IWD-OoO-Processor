frontend_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating instruction queue

_start:
# initialize
li x1, 1
li x1, 2
li x1, 3
li x1, 4
li x1, 5
li x1, 6
li x1, 7
li x1, 8
li x1, 9
li x1, 10
li x1, 11
li x1, 12
li x1, 13
li x1, 14
li x1, 15
li x1, 16


halt:
    slti x0, x0, -256
