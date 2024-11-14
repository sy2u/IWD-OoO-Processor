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
    bne x0, x0, end_loop
    li x1, 1
    li x1, 1
    li x1, 1
    li x1, 1
    li x1, 1
    jal x1, loop
end_loop:
li x2, 1
li x2, 1
nop
nop
nop
nop
nop
nop
nop
nop
nop


halt:
    slti x0, x0, -256

