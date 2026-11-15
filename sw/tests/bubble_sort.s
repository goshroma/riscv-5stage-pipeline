    li   s0, 0x100
    li   s1, 12

    li   t0, 0x29
    sw   t0, 0(s0)
    li   t0, -5
    sw   t0, 4(s0)
    li   t0, 0x7fff
    sw   t0, 8(s0)
    li   t0, 3
    sw   t0, 12(s0)
    li   t0, 0
    sw   t0, 16(s0)
    li   t0, -1000
    sw   t0, 20(s0)
    li   t0, 88
    sw   t0, 24(s0)
    li   t0, 3
    sw   t0, 28(s0)
    li   t0, 1
    sw   t0, 32(s0)
    li   t0, -2
    sw   t0, 36(s0)
    li   t0, 500
    sw   t0, 40(s0)
    li   t0, 42
    sw   t0, 44(s0)

    addi s2, s1, -1
outer:
    li   t1, 0
    mv   t2, s0
    li   s3, 0
inner:
    lw   t3, 0(t2)
    lw   t4, 4(t2)
    ble  t3, t4, noswap
    sw   t4, 0(t2)
    sw   t3, 4(t2)
    li   s3, 1
noswap:
    addi t2, t2, 4
    addi t1, t1, 1
    blt  t1, s2, inner
    beqz s3, sorted
    addi s2, s2, -1
    bnez s2, outer
sorted:
    li   a0, 0
    li   t1, 0
    mv   t2, s0
check:
    lw   t3, 0(t2)
    lw   t4, 4(t2)
    bgt  t3, t4, fail
    addi t2, t2, 4
    addi t1, t1, 1
    addi t5, s1, -1
    blt  t1, t5, check
    li   a0, 1
fail:
    sw   a0, 0(x0)
    ecall
