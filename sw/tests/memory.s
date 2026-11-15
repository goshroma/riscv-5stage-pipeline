    li   x1, 0x40
    li   x2, 0x8899aabb
    sw   x2, 0(x1)
    lb   x3, 0(x1)
    lb   x4, 1(x1)
    lb   x5, 2(x1)
    lb   x6, 3(x1)
    lbu  x7, 0(x1)
    lbu  x8, 3(x1)
    lh   x9, 0(x1)
    lh   x10, 2(x1)
    lhu  x11, 0(x1)
    lhu  x12, 2(x1)
    lw   x13, 0(x1)

    li   x14, 0x11223344
    sw   x14, 4(x1)
    li   x15, 0xee
    sb   x15, 4(x1)
    sb   x15, 6(x1)
    li   x16, 0x7f01
    sh   x16, 8(x1)
    sh   x16, 10(x1)
    lw   x17, 4(x1)
    lw   x18, 8(x1)

    li   x19, 0x80
    li   x20, 0
    li   x21, 16
fill:
    sw   x20, 0(x19)
    addi x19, x19, 4
    addi x20, x20, 1
    blt  x20, x21, fill

    li   x19, 0x80
    li   x22, 0
    li   x20, 0
sum:
    lw   x23, 0(x19)
    add  x22, x22, x23
    addi x19, x19, 4
    addi x20, x20, 1
    blt  x20, x21, sum
    sw   x22, -4(x1)
    ecall
