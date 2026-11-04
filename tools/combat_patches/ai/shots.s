.intel_syntax noprefix
.code64
.set PROJECTILE_BEHAVIOUR, 0x143a9dfd0
.set FORCE_WALL_BEHAVIOUR, 0x143a9ef78
.set COUNTERS, 0x1537376e0
.set C_EVALUATED, 0
.set C_FALLBACKS, 4
.set C_LAST_DAMAGE, 8
.set C_REASON, 0xc
.set REASON_BEHAVIOUR, 1
.set REASON_PROVIDER, 2
.set REASON_NO_OWNER, 3
.set REASON_NOT_EVALUATED, 4
.set REASON_NOT_POSITIVE, 5
.set TREE_STEPS, 64
start:
    push rsi
    push rdi
    sub rsp, 0x108
    movabs rax, 0x1408b0e80
    call rax
    mov qword ptr [rsp + 0x20], rax
    mov rdi, qword ptr [rbx + 0x10]
    call heap
    test al, al
    je done
    movabs rax, 0x143a5c468
    cmp qword ptr [rdi], rax
    jne done
    movabs rax, 0x143a5bf40
    cmp qword ptr [rdi - 0x280], rax
    jne done
    mov rdi, qword ptr [rdi - 0x280 + 0x1b8]
    call heap
    test al, al
    je done
    mov rdi, qword ptr [rdi]
    call heap
    test al, al
    je done
    sub rdi, 8
    movabs rax, 0x143a75900
    cmp qword ptr [rdi], rax
    jne done
    cmp qword ptr [rdi + 0x2b8], 0
    jne done
    movabs rax, 0x153737608
    mov rax, qword ptr [rax]
    test rax, rax
    jne target_choice
    movabs rax, 0x142b38010
target_choice:
    mov rcx, rdi
    call rax
    mov rsi, rax
    test rsi, rsi
    je done
    lea rdi, [rsp + 0x30]
    xor eax, eax
    mov ecx, 0xd0 / 8
    rep stosq
    lea rax, [rsi + 8]
    mov qword ptr [rsp + 0xf8], rax
    lea rax, [rsp + 0xf8]
    mov qword ptr [rsp + 0x68], rax
    call weapon_damage
    movss dword ptr [rsp + 0xd0], xmm0
    movabs rax, 0x144759e70
    mov rax, qword ptr [rax]
    test rax, rax
    je done
    lea rdx, [rsp + 0x30]
    mov ecx, 1
    call rax
done:
    mov rax, qword ptr [rsp + 0x20]
    add rsp, 0x108
    pop rdi
    pop rsi
    ret
weapon_damage:
    sub rsp, 0x28
    mov r11d, REASON_BEHAVIOUR
    mov rax, qword ptr [rbx]
    movabs rdx, PROJECTILE_BEHAVIOUR
    cmp rax, rdx
    je 1f
    movabs rdx, FORCE_WALL_BEHAVIOUR
    cmp rax, rdx
    jne fallback
1:
    mov rdi, qword ptr [rbx + 0x28]
    call heap
    test al, al
    je fallback
    mov rdi, qword ptr [rdi + 0xf0]
    call heap
    test al, al
    je fallback
    mov r11d, REASON_PROVIDER
    cmp qword ptr [rdi + 0x40], 0
    jne fallback
    mov r9, qword ptr [rdi + 0x38]
    test r9, r9
    jne 2f
    movss xmm0, dword ptr [rdi + 0x48]
    jmp evaluated
2:
    mov r11d, REASON_NO_OWNER
    mov rdi, qword ptr [rbx + 0x18]
    call heap
    test al, al
    je fallback
    mov r11d, REASON_NOT_EVALUATED
    lea r10, [rdi + 0x50]
    mov rcx, r10
    mov rdi, qword ptr [rdi + 0x60]
    mov r8d, TREE_STEPS
3:
    test rdi, rdi
    je 5f
    dec r8d
    je fallback
    call heap
    test al, al
    je fallback
    cmp qword ptr [rdi + 0x20], r9
    jb 4f
    mov rcx, rdi
    mov rdi, qword ptr [rdi + 8]
    jmp 3b
4:
    mov rdi, qword ptr [rdi]
    jmp 3b
5:
    cmp rcx, r10
    je fallback
    cmp r9, qword ptr [rcx + 0x20]
    jb fallback
    mov rdi, qword ptr [rcx + 0x28]
    call heap
    test al, al
    je fallback
    mov rax, qword ptr [rdi]
    movabs rdx, 0x140000000
    cmp rax, rdx
    jb fallback
    movabs rdx, 0x154000000
    cmp rax, rdx
    jae fallback
    mov rcx, rdi
    mov dl, 1
    call qword ptr [rax + 0x30]
evaluated:
    mov r11d, REASON_NOT_POSITIVE
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe fallback
    movabs rax, COUNTERS
    inc dword ptr [rax + C_EVALUATED]
    movss dword ptr [rax + C_LAST_DAMAGE], xmm0
    add rsp, 0x28
    ret
fallback:
    movabs rax, COUNTERS
    inc dword ptr [rax + C_FALLBACKS]
    mov dword ptr [rax + C_REASON], r11d
    movss xmm0, dword ptr [rip + shot_damage]
    add rsp, 0x28
    ret
heap:
    xor eax, eax
    test dil, 7
    jne 1f
    cmp rdi, 0x10000
    jb 1f
    movabs rdx, 0x7ff000000000
    cmp rdi, rdx
    jae 1f
    mov al, 1
1:
    ret
.balign 4
shot_damage:
    .float 100.0
