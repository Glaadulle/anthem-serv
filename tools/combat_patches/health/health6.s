.intel_syntax noprefix
.code64
start:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 0x90
    mov rsi, rdx
    mov rdi, rdx
    call heap
    test al, al
    je done
    mov rdi, qword ptr [rsi + 0x38]
    call heap
    test al, al
    je done
    mov rdi, qword ptr [rdi]
    call heap
    test al, al
    je done
    lea rbx, [rdi - 8]
    mov rcx, rbx
    call image_table
    test al, al
    je done
    movss xmm1, dword ptr [rsi + 0xa0]
    xorps xmm0, xmm0
    comiss xmm1, xmm0
    jbe done
    mov eax, 0x47c35000
    movd xmm0, eax
    comiss xmm1, xmm0
    jae done
    comiss xmm1, dword ptr [rip + projectile_threshold]
    jae amount_ready
    mulss xmm1, dword ptr [rip + projectile_scale]
amount_ready:
    movss dword ptr [rsp + 0x24], xmm1
    mov qword ptr [rsp + 0x38], rbx
    lea rax, [rsp + 0x38]
    mov qword ptr [rsp + 0x30], rax
    lea rcx, [rsp + 0x28]
    movabs rax, 0x140c86ef0
    call rax
    mov rdi, qword ptr [rbx + 0x58]
    call heap
    test al, al
    je done
    movzx r13d, byte ptr [rdi + 8]
    lea r12, [rdi + 0x10]
find:
    test r13d, r13d
    je placeable
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je next
    movabs rax, 0x143a88538
    cmp qword ptr [rdi], rax
    jne next
    mov rax, qword ptr [rdi + 8]
    cmp rax, qword ptr [rbx + 0x58]
    je found
next:
    add r12, 0x20
    dec r13d
    jmp find
found:
    mov r12, rdi
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je done
    cmp byte ptr [rdi + 0x12f], 0
    jne done
    mov rax, qword ptr [rbx + 0x58]
    movzx ecx, byte ptr [rax + 8]
    lea rdx, [rax + 0x10]
shield_find:
    test ecx, ecx
    je shield_none
    mov r8, qword ptr [rdx + 0x10]
    test r8, r8
    je shield_next
    movabs r9, 0x143a76ae0
    cmp qword ptr [r8], r9
    jne shield_next
    mov r8, qword ptr [r8 + 0x50]
    test r8, r8
    je shield_none
    test r8b, 3
    jne shield_none
    movss xmm0, dword ptr [r8]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe shield_none
    movss xmm1, dword ptr [rsp + 0x24]
    mulss xmm1, dword ptr [rip + inverse_k]
    mulss xmm1, dword ptr [rip + shield_scale]
    subss xmm0, xmm1
    maxss xmm0, xmm2
    movss dword ptr [r8], xmm0
    jmp done
shield_next:
    add rdx, 0x20
    dec ecx
    jmp shield_find
shield_none:
    movss xmm0, dword ptr [r12 + 0x20]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    jbe done
    movss xmm1, dword ptr [rsp + 0x24]
    movss xmm2, dword ptr [rip + inverse_k]
    mulss xmm1, xmm2
    subss xmm0, xmm1
    xorps xmm2, xmm2
    maxss xmm0, xmm2
    movss dword ptr [r12 + 0x20], xmm0
    movss dword ptr [rsp + 0x88], xmm0
    mov qword ptr [rsp + 0x80], rbx
    movabs rax, 0x153737800
    mov r13d, dword ptr [rax]
    cmp r13d, 64
    ja character_death
    lea rbx, [rax + 0x10]
pair:
    test r13d, r13d
    je character_death
    cmp qword ptr [rbx], r12
    jne pair_next
    mov rdi, qword ptr [rbx + 8]
    movabs rdx, 0x143a8d310
    call live_component
    test al, al
    je pair_next
    movss dword ptr [rdi + 0x20], xmm0
pair_next:
    add rbx, 0x10
    dec r13d
    jmp pair
character_death:
    mov rbx, qword ptr [rsp + 0x80]
    movss xmm0, dword ptr [rsp + 0x88]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    ja done
    test byte ptr [r12 + 0x158], 3
    jne done
    mov al, byte ptr [r12 + 0x158]
    and al, 0xfc
    or al, 2
    mov byte ptr [r12 + 0x158], al
    lea rdi, [rsp + 0x40]
    xor eax, eax
    mov ecx, 8
    rep stosq
    movabs rax, 0x143a8b580
    mov qword ptr [rsp + 0x40], rax
    mov dword ptr [rsp + 0x48], 0xb7d01296
    mov dword ptr [rsp + 0x4c], 0xfae11fc1
    mov dword ptr [rsp + 0x50], 0xff
    lea rax, [rbx + 0x610]
    mov qword ptr [rsp + 0x70], rax
    mov rax, qword ptr [rbx + 0x58]
    lea r13, [rax + 0x10]
    movzx edi, byte ptr [rax + 8]
    shl rdi, 5
    add rdi, r13
death_broadcast:
    cmp r13, rdi
    jae death_bus
    test dword ptr [r13 + 4], 0x800
    je death_next
    mov rcx, qword ptr [r13 + 0x10]
    mov rax, qword ptr [rcx]
    lea rdx, [rsp + 0x40]
    call qword ptr [rax + 0xa0]
death_next:
    add r13, 0x20
    jmp death_broadcast
death_bus:
    movabs rax, 0x1446ceca0
    mov rax, qword ptr [rax]
    test rax, rax
    je death_killed
    mov rcx, qword ptr [rax + 0x20]
    test rcx, rcx
    je death_killed
    lea rdx, [rsp + 0x40]
    movabs rax, 0x1403e7c60
    call rax
death_killed:
    mov rcx, r12
    movabs rax, 0x1415d0950
    call rax
    mov rax, qword ptr [rsi + 0x38]
    mov qword ptr [rsp + 0x80], rax
    lea r8, [rsp - 0x40]
    xor ecx, ecx
    xor edx, edx
    mov r9d, 1
    movabs rax, 0x1408fc7b0
    call rax
    jmp done
placeable:
    mov rdi, qword ptr [rbx + 0x58]
    movzx r13d, byte ptr [rdi + 8]
    lea r12, [rdi + 0x10]
placeable_find:
    test r13d, r13d
    je unhandled
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je placeable_next
    movabs rax, 0x143a740a0
    cmp qword ptr [rdi], rax
    jne placeable_next
    mov rax, qword ptr [rdi + 8]
    cmp rax, qword ptr [rbx + 0x58]
    je placeable_found
placeable_next:
    add r12, 0x20
    dec r13d
    jmp placeable_find
placeable_found:
    mov r12, rdi
    mov rdi, qword ptr [r12 + 0x10]
    call heap
    test al, al
    je done
    cmp byte ptr [rdi + 0xe2], 0
    jne done
    test byte ptr [r12 + 0x100], 3
    jne done
    movss xmm0, dword ptr [r12 + 0x24]
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    ja placeable_ready
    mov eax, 0x3f800000
    mov dword ptr [r12 + 0x24], eax
    mov dword ptr [r12 + 0x20], eax
placeable_ready:
    movss xmm3, dword ptr [rdi + 0xa0]
    xorps xmm2, xmm2
    comiss xmm3, xmm2
    ja placeable_scale
    mov eax, 0x42c80000
    movd xmm3, eax
placeable_scale:
    movss xmm1, dword ptr [rsp + 0x24]
    mulss xmm1, dword ptr [rip + inverse_k]
    mov eax, 0x42c80000
    movd xmm2, eax
    mulss xmm1, xmm2
    divss xmm1, xmm3
    movss xmm0, dword ptr [r12 + 0x20]
    subss xmm0, xmm1
    xorps xmm2, xmm2
    maxss xmm0, xmm2
    movss dword ptr [r12 + 0x20], xmm0
    mov ecx, 1
    movabs rdx, 0x153737f80
    lock xadd dword ptr [rdx], ecx
    and ecx, 7
    mov qword ptr [rdx + rcx*8 + 0x10], r12
    xorps xmm2, xmm2
    comiss xmm0, xmm2
    ja done
    mov dword ptr [r12 + 0x100], 2
    lea rcx, [rbx + 0x170]
    xor edx, edx
    movabs rax, 0x140959e00
    call rax
    mov rcx, qword ptr [rbx + 0x28]
    mov rdx, qword ptr [r12 + 0x10]
    mov r8d, 0xa96f26e7
    movabs rax, 0x141b465b0
    call rax
    mov rdi, qword ptr [r12 + 0x1f0]
    call heap
    test al, al
    je done
    mov byte ptr [rsp + 0x20], 1
    mov rcx, rdi
    lea rdx, [rsp + 0x20]
    movabs rax, 0x1403fa290
    call rax
    jmp done
unhandled:
    mov ecx, 1
    movabs rdx, 0x153737fd0
    lock xadd dword ptr [rdx], ecx
    mov eax, ecx
    xor edx, edx
    mov ecx, 5
    div ecx
    movabs rcx, 0x153737fd8
    mov rax, qword ptr [rbx]
    mov qword ptr [rcx + rdx*8], rax
done:
    add rsp, 0x90
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
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
live_component:
    xor eax, eax
    test dil, 7
    jne 3f
    cmp rdi, 0x10000
    jb 3f
    movabs rcx, 0x7ff000000000
    cmp rdi, rcx
    jae 3f
    cmp qword ptr [rdi], rdx
    jne 3f
    mov rcx, qword ptr [rdi + 8]
    test cl, 7
    jne 3f
    cmp rcx, 0x10000
    jb 3f
    movabs rdx, 0x7ff000000000
    cmp rcx, rdx
    jae 3f
    movzx edx, byte ptr [rcx + 8]
    add rcx, 0x20
4:
    test edx, edx
    je 3f
    cmp qword ptr [rcx], rdi
    je 5f
    add rcx, 0x20
    dec edx
    jmp 4b
5:
    mov al, 1
3:
    ret
image_table:
    xor eax, eax
    mov rcx, qword ptr [rcx]
    movabs rdx, 0x143660000
    cmp rcx, rdx
    jb 2f
    movabs rdx, 0x1442f0000
    cmp rcx, rdx
    jae 2f
    mov al, 1
2:
    ret
.balign 4
projectile_threshold:
    .float 100.0
projectile_scale:
    .float 85.0
shield_scale:
    .float 1000.0
inverse_k:
    .float 0.00005
