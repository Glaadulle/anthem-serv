.intel_syntax noprefix
.code64
.set NEAREST_PLAYER, 0x142b38010
range_to_target:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x20
    mov rbx, rcx
    call context_entity
    test rax, rax
    je range_false
    mov rdi, rax
    mov rcx, rax
    movabs rax, NEAREST_PLAYER
    call rax
    mov rsi, rax
    test rsi, rsi
    je range_false
    mov rax, rdi
    movss xmm0, dword ptr [rax + 0x1b4]
    subss xmm0, dword ptr [rsi + 0x1b4]
    mulss xmm0, xmm0
    cmp byte ptr [rbx + 0x31], 0
    jne range_distance
    cmp byte ptr [rbx + 0x30], 0
    je range_planar
    xorps xmm0, xmm0
range_planar:
    movss xmm1, dword ptr [rax + 0x1b0]
    subss xmm1, dword ptr [rsi + 0x1b0]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    movss xmm1, dword ptr [rax + 0x1b8]
    subss xmm1, dword ptr [rsi + 0x1b8]
    mulss xmm1, xmm1
    addss xmm0, xmm1
range_distance:
    sqrtss xmm0, xmm0
    movss xmm1, dword ptr [rbx + 0x2c]
    mov ecx, dword ptr [rbx + 0x28]
    xor eax, eax
    cmp ecx, 2
    je range_less
    cmp ecx, 3
    je range_more
    cmp ecx, 4
    je range_less_equal
    cmp ecx, 5
    je range_more_equal
    cmp ecx, 1
    je range_not_equal
    comiss xmm0, xmm1
    sete al
    jmp range_done
range_not_equal:
    comiss xmm0, xmm1
    setne al
    jmp range_done
range_less:
    comiss xmm0, xmm1
    setb al
    jmp range_done
range_more:
    comiss xmm0, xmm1
    seta al
    jmp range_done
range_less_equal:
    comiss xmm0, xmm1
    setbe al
    jmp range_done
range_more_equal:
    comiss xmm0, xmm1
    setae al
    jmp range_done
range_false:
    xor eax, eax
range_done:
    add rsp, 0x20
    pop rdi
    pop rsi
    pop rbx
    ret
context_entity:
    sub rsp, 0x28
    mov rax, qword ptr [rdx]
    mov rcx, rdx
    call qword ptr [rax + 0x10]
    test rax, rax
    je context_none
    mov rcx, rax
    movabs rax, 0x1403992f0
    call rax
    test rax, rax
    je context_none
    movabs rcx, 0x143a75900
    cmp qword ptr [rax], rcx
    je context_done
context_none:
    xor eax, eax
context_done:
    add rsp, 0x28
    ret
.balign 16
ai_target:
    push rbx
    sub rsp, 0x30
    mov qword ptr [rsp + 0x20], rdx
    movabs rax, 0x148cc8d00
    call rax
    test rax, rax
    jne target_done
    mov rdx, qword ptr [rsp + 0x20]
    call context_entity
    test rax, rax
    je target_done
    mov rcx, rax
    movabs rax, NEAREST_PLAYER
    call rax
target_done:
    add rsp, 0x30
    pop rbx
    ret
.balign 16
wants_to_attack:
    mov rax, qword ptr [rcx + 0x10]
    movabs rdx, 0x145280710
    cmp rax, rdx
    sete al
    ret
