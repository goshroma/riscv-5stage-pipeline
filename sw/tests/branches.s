    li   x1, 5
    li   x2, -3
    li   x3, 5
    li   x20, 0

    beq  x1, x3, t1
    addi x20, x20, 1
t1: bne  x1, x3, bad
    blt  x2, x1, t2
    addi x20, x20, 2
t2: bge  x2, x1, bad
    bltu x1, x2, t3
    addi x20, x20, 4
t3: bgeu x1, x2, bad
    bge  x1, x3, t4
    addi x20, x20, 8
t4: blt  x1, x3, bad
    bgeu x2, x1, t5
    addi x20, x20, 16
t5:
    li   x4, 0
    li   x5, 10
loop:
    addi x4, x4, 3
    addi x5, x5, -1
    bnez x5, loop

    jal  ra, func
    addi x6, x6, 100
    j    after
func:
    li   x6, 7
    ret
after:
    auipc x7, 0
    jalr  x8, 12(x7)
    addi  x31, x0, 1
    li    x9, 0x55

    li   x10, 0
    li   x11, 8
count:
    addi x10, x10, 1
    blt  x10, x11, count

    beq  x0, x0, done
bad:
    li   x30, 0xdead
done:
    sw   x20, 0(x0)
    sw   x4, 4(x0)
    ecall
    li   x29, 0xffff
    sw   x29, 8(x0)
