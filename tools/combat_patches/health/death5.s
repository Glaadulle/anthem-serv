.intel_syntax noprefix
.code64
start:
    push rcx
    push rdx
    push r8
    push r9
    push rbx
    push rsi
    push rdi
    sub rsp, 0x30
    movabs rsi, 0x153737f00
    mov edx, 8
placeable_slot:
    xor ebx, ebx
    xchg qword ptr [rsi], rbx
    test rbx, rbx
    je placeable_next
    mov qword ptr [rsp + 0x20], rdx
    mov rdi, rbx
    movabs rdx, 0x143a24ff0
    call live_component
    mov rdx, qword ptr [rsp + 0x20]
    test al, al
    je placeable_next
    mov qword ptr [rsp + 0x20], rdx
    movss xmm0, dword ptr [rbx + 0x24]
    xorps xmm1, xmm1
    comiss xmm0, xmm1
    ja placeable_apply
    mov dword ptr [rbx + 0x24], 0x3f800000
    mov dword ptr [rbx + 0x20], 0x3f800000
placeable_apply:
    mov rcx, rbx
    movss xmm1, dword ptr [rsi + 8]
    mov r8d, dword ptr [rsi + 12]
    movabs rax, 0x1408b8730
    call rax
    mov rdx, qword ptr [rsp + 0x20]
placeable_next:
    add rsi, 16
    dec edx
    jne placeable_slot
    add rsp, 0x30
    pop rdi
    pop rsi
    pop rbx
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp qword ptr [rip]
    .quad 0x1480e8810
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
