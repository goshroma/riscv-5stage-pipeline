    li   a0, 0x300
    li   a1, 30
    li   t0, 0
    li   t1, 1
    sw   t0, 0(a0)
    sw   t1, 4(a0)
    addi a2, a0, 8
    li   t2, 2
fib:
    add  t3, t0, t1
    sw   t3, 0(a2)
    mv   t0, t1
    mv   t1, t3
    addi a2, a2, 4
    addi t2, t2, 1
    blt  t2, a1, fib
    mv   a3, t3
    ecall
