    li   x1, 10
    addi x2, x1, 1
    addi x3, x2, 1
    add  x4, x2, x3
    add  x5, x4, x4
    nop
    add  x6, x5, x1

    addi x7, x0, 3
    addi x7, x7, 4
    addi x7, x7, 5
    add  x8, x7, x7

    li   x9, 0x100
    sw   x8, 0(x9)
    lw   x10, 0(x9)
    add  x11, x10, x10
    lw   x12, 0(x9)
    nop
    add  x13, x12, x1
    lw   x14, 0(x9)
    sw   x14, 4(x9)
    lw   x15, 4(x9)
    beq  x15, x8, ok1
    li   x31, 0xbad
ok1:
    lw   x16, 4(x9)
    addi x16, x16, 1
    sw   x16, 8(x9)

    addi x0, x0, 55
    add  x17, x0, x0

    addi x18, x0, 1
    addi x19, x0, 2
    addi x20, x0, 3
    add  x21, x18, x0
    add  x21, x21, x19
    add  x21, x21, x20

    li   x22, 0x200
    addi x23, x0, 77
    sw   x23, 0(x22)
    sb   x23, 5(x22)
    lbu  x24, 5(x22)
    lw   x25, 0(x22)
    sub  x26, x25, x24
    ecall
