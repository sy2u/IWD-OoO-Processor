frontend_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating instruction queue

_start:
# initialize
li x1, 1
li x2, 2
li x3, 3
li x4, 4
li x5, 5
li x6, 6
li x7, 7
li x8, 8
li x9, 9
li x20, 2048
li x21, 4096
li x22, 8192


lb x11, 0(x1)
lb x11, 0(x2)
lb x11, 0(x3)
lb x11, 0(x4)
lb x11, 0(x5)
lb x11, 0(x6)
lb x11, 0(x7)

sw x12, 512(x0)
sw x12, 1024(x0)
sw x12, 1536(x0)
sw x12, 0(x20)
sw x12, 0(x21)
sw x12, 0(x22)



halt:
    slti x0, x0, -256
