.intel_syntax noprefix
.code64
.set COMPUTE_DAMAGE, 0x140c162f0
.set SET_HEALTH, 0x142b2e400
.set REPLICATE, 0x142b2e5f0
.set SIMPLE_HEALTH_TABLE, 0x143a88538
.set INVULNERABLE_PLAYER, 0x1537377ec
.set SHIELD_TABLE, 0x143a76ae0
.set DYING_MESSAGE_TABLE, 0x143a8b648
.set DEATH_MESSAGE_TABLE, 0x143a8b580
.set ON_KILLED, 0x1415d0950
.set CHARACTER_KILLED, 0x1408fc7b0
.set INTERFACE, 0xa8
.set MARK_DIRTY, 0x141e5e2c0
.macro health_message table, id, name
    lea rdi, [rsp + 0x40]
    xor eax, eax
    mov ecx, 8
    rep stosq
    movabs rax, \table
    mov qword ptr [rsp + 0x40], rax
    mov dword ptr [rsp + 0x48], 0xb7d01296
    mov dword ptr [rsp + 0x4c], \id
    mov dword ptr [rsp + 0x50], 0xff
    lea rax, [r13 + 0x610]
    mov qword ptr [rsp + 0x70], rax
    mov rax, qword ptr [r13 + 0x58]
    lea r14, [rax + 0x10]
    movzx edi, byte ptr [rax + 8]
    shl rdi, 5
    add rdi, r14
\name\()_components:
    cmp r14, rdi
    jae \name\()_bus
    test dword ptr [r14 + 4], 0x800
    je \name\()_next
    mov rcx, qword ptr [r14 + 0x10]
    mov rax, qword ptr [rcx]
    lea rdx, [rsp + 0x40]
    call qword ptr [rax + 0xa0]
\name\()_next:
    add r14, 0x20
    jmp \name\()_components
\name\()_bus:
    movabs rax, 0x1446ceca0
    mov rax, qword ptr [rax]
    test rax, rax
    je \name\()_sent
    mov rcx, qword ptr [rax + 0x20]
    test rcx, rcx
    je \name\()_sent
    lea rdx, [rsp + 0x40]
    movabs rax, 0x1403e7c60
    call rax
\name\()_sent:
.endm
apply_damage:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    sub rsp, 0x118
    mov rbx, rcx
    mov rsi, rdx
    mov rdi, r8
    lea r12, [rcx - INTERFACE]
    mov rax, qword ptr [r12 + 8]
    mov r13, qword ptr [rax]
    cmp qword ptr [r12 + 0x160], 0
    jne shield_ready
    mov rax, qword ptr [r13 + 0x58]
    movzx ecx, byte ptr [rax + 8]
    lea rdx, [rax + 0x10]
shield_find:
    test ecx, ecx
    je shield_ready
    mov r8, qword ptr [rdx + 0x10]
    test r8, r8
    je shield_next
    movabs r9, SHIELD_TABLE
    cmp qword ptr [r8], r9
    jne shield_next
    add r8, 0x30
    mov qword ptr [r12 + 0x160], r8
    jmp shield_ready
shield_next:
    add rdx, 0x20
    dec ecx
    jmp shield_find
shield_ready:
    mov rax, qword ptr [r12 + 0x160]
    test rax, rax
    je shield_on
    mov rcx, qword ptr [rax + 0x20]
    test rcx, rcx
    je shield_on
    cmp byte ptr [rcx + 9], 0
    jne shield_on
    movss xmm0, dword ptr [rax + 0x28]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jbe shield_on
    mov byte ptr [rcx + 9], 1
    lea rcx, [rax + 0xe0]
    mov edx, 7
    movabs rax, MARK_DIRTY
    call rax
shield_on:
    or byte ptr [rdi + 0x16a], 0x20
    mov rcx, rbx
    mov rdx, rsi
    mov r8, rdi
    movabs rax, COMPUTE_DAMAGE
    call rax
    test byte ptr [r12 + 0x158], 3
    jne done
    movss xmm0, dword ptr [rsi + 4]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe done
    mov rax, qword ptr [r12 + 0x10]
    cmp byte ptr [rax + 0x12f], 0
    jne done
    movabs rax, SIMPLE_HEALTH_TABLE
    cmp qword ptr [r12], rax
    je vulnerable
    movabs rax, INVULNERABLE_PLAYER
    cmp byte ptr [rax], 0
    jne done
vulnerable:
    movss xmm1, dword ptr [r12 + 0x20]
    subss xmm1, xmm0
    maxss xmm1, xmm2
    movss dword ptr [rsp + 0x88], xmm1
    mov rcx, r12
    movabs rax, SET_HEALTH
    call rax
    movss xmm0, dword ptr [rsp + 0x88]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    ja done
    or byte ptr [r12 + 0x158], 1
    health_message DYING_MESSAGE_TABLE, 0x6b3a91e0, dying
    movabs rax, SIMPLE_HEALTH_TABLE
    cmp qword ptr [r12], rax
    jne replicate_state
    mov al, byte ptr [r12 + 0x158]
    and al, 0xfc
    or al, 2
    mov byte ptr [r12 + 0x158], al
    health_message DEATH_MESSAGE_TABLE, 0xfae11fc1, death
    mov rcx, r12
    mov edx, 8
    movabs rax, REPLICATE
    call rax
    mov rcx, r12
    movabs rax, ON_KILLED
    call rax
    lea rax, [r13 + 8]
    mov qword ptr [rsp + 0xf0], rax
    lea rax, [rsp + 0xf0]
    mov qword ptr [rsp + 0xe0], rax
    lea r8, [rsp + 0x20]
    xor ecx, ecx
    xor edx, edx
    mov r9d, 1
    movabs rax, CHARACTER_KILLED
    call rax
    jmp done
replicate_state:
    mov rcx, r12
    mov edx, 8
    movabs rax, REPLICATE
    call rax
done:
    mov rax, rsi
    add rsp, 0x118
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
