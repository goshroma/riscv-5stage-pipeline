    li   x1, 0x7fffffff
    li   x2, 0x80000000
    li   x3, -1
    li   x4, 5
    li   x5, -7

    add  x6, x1, x4
    sub  x7, x2, x4
    sub  x8, x4, x5
    and  x9, x1, x5
    or   x10, x2, x4
    xor  x11, x3, x1
    slt  x12, x2, x1
    slt  x13, x1, x2
    sltu x14, x2, x1
    sltu x15, x4, x3
    sll  x16, x4, x4
    srl  x17, x2, x4
    sra  x18, x2, x4
    sra  x19, x5, x4

    addi  x20, x1, 1
    addi  x21, x0, -2048
    andi  x22, x3, 0x7ff
    ori   x23, x0, -1
    xori  x24, x4, -1
    slti  x25, x5, -6
    sltiu x26, x4, -1
    slli  x27, x3, 31
    srli  x28, x3, 28
    srai  x29, x2, 31
    lui   x30, 0xabcde
    auipc x31, 0x10

    sw   x6, 0(x0)
    sw   x7, 4(x0)
    sw   x8, 8(x0)
    sw   x18, 12(x0)
    ecall
