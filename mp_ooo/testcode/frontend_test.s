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
li x1, 17
li x1, 18
li x1, 19
li x1, 20
li x1, 21
li x1, 22
li x1, 23
li x1, 24
li x1, 25
li x1, 26
li x1, 27
li x1, 28
li x1, 29
li x1, 30
li x1, 31
li x1, 32


halt:
    slti x0, x0, -256
