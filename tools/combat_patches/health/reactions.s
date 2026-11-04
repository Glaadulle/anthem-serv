.intel_syntax noprefix
.code64
.set SET_HEALTH, 0x140cba3a0
.set OWNER, 0x140899530
.set INFO_CONSTRUCT, 0x1408f09d0
.set INFO_DESTRUCT, 0x1408f0b70
.set AI_CLIENT_HEALTH, 0x143a8d310
.set MESSAGE_TABLE, 0x143a821b8
.set SIMULATION_RECEIVE, 0x140bcd8c0
.set OLD_HEALTH, 0x28
.set LOST, 0x2c
.set MESSAGE, 0x40
.set RESULT, 0x90
.set INFO, 0xe0
replicated_health:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 0x2c0
    mov rbx, rcx
    movss xmm0, dword ptr [rcx + 0x20]
    movss dword ptr [rsp + OLD_HEALTH], xmm0
    movabs rax, SET_HEALTH
    call rax
    movabs rax, AI_CLIENT_HEALTH
    cmp qword ptr [rbx], rax
    jne done
    movss xmm0, dword ptr [rsp + OLD_HEALTH]
    subss xmm0, dword ptr [rbx + 0x20]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe done
    movss dword ptr [rsp + LOST], xmm0
    mov rax, qword ptr [rbx + 8]
    test rax, rax
    je done
    mov rcx, qword ptr [rax]
    movabs rax, OWNER
    call rax
    test rax, rax
    je done
    mov r12, rax
    mov rax, qword ptr [r12 + 0x58]
    lea rsi, [rax + 0x10]
    movzx edi, byte ptr [rax + 8]
    shl rdi, 5
    add rdi, rsi
    movabs r13, SIMULATION_RECEIVE
simulations:
    cmp rsi, rdi
    jae simulations_ready
    test dword ptr [rsi + 4], 0x800
    je next_simulation
    mov rcx, qword ptr [rsi + 0x10]
    mov rax, qword ptr [rcx]
    cmp qword ptr [rax + 0xa0], r13
    jne next_simulation
    mov rax, qword ptr [rcx + 0xf0]
    movsxd rax, dword ptr [rax + 4]
    cmp qword ptr [rcx + rax + 0x178], 0
    je done
next_simulation:
    add rsi, 0x20
    jmp simulations
simulations_ready:
    lea rcx, [rsp + INFO]
    movabs rax, INFO_CONSTRUCT
    call rax
    movss xmm0, dword ptr [rsp + LOST]
    movss dword ptr [rsp + INFO + 0xd0], xmm0
    lea rdi, [rsp + RESULT]
    xor eax, eax
    mov ecx, 8
    rep stosq
    movss dword ptr [rsp + RESULT + 4], xmm0
    mov byte ptr [rsp + RESULT + 0x35], 1
    mov byte ptr [rsp + RESULT + 0x36], 1
    lea rdi, [rsp + MESSAGE]
    xor eax, eax
    mov ecx, 8
    rep stosq
    movabs rax, MESSAGE_TABLE
    mov qword ptr [rsp + MESSAGE], rax
    mov dword ptr [rsp + MESSAGE + 8], 0x72733d28
    mov dword ptr [rsp + MESSAGE + 0xc], 0x84e38c29
    mov dword ptr [rsp + MESSAGE + 0x10], 0xff
    lea rax, [rsp + INFO]
    mov qword ptr [rsp + MESSAGE + 0x30], rax
    lea rax, [rsp + RESULT]
    mov qword ptr [rsp + MESSAGE + 0x38], rax
    mov rax, qword ptr [r12 + 0x58]
    lea rsi, [rax + 0x10]
    movzx edi, byte ptr [rax + 8]
    shl rdi, 5
    add rdi, rsi
components:
    cmp rsi, rdi
    jae sent
    test dword ptr [rsi + 4], 0x800
    je next
    mov rcx, qword ptr [rsi + 0x10]
    mov rax, qword ptr [rcx]
    lea rdx, [rsp + MESSAGE]
    call qword ptr [rax + 0xa0]
next:
    add rsi, 0x20
    jmp components
sent:
    lea rcx, [rsp + INFO]
    movabs rax, INFO_DESTRUCT
    call rax
done:
    add rsp, 0x2c0
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
