.intel_syntax noprefix
.code64
start:
    push rcx
    push rdx
    push r8
    push r9
    push rbx
    push rsi
    sub rsp, 0x28
    movabs rsi, 0x153737e60
    mov edx, 16
slot:
    xor ebx, ebx
    xchg qword ptr [rsi], rbx
    test rbx, rbx
    je next
    test bl, 7
    jne next
    cmp rbx, 0x10000
    jb next
    movabs rax, 0x7ff000000000
    cmp rbx, rax
    jae next
    movabs rax, 0x143a8d310
    cmp qword ptr [rbx], rax
    jne next
    cmp dword ptr [rbx + 0x188], 0
    jne next
    mov qword ptr [rsp + 0x20], rdx
    mov rcx, rbx
    xorps xmm1, xmm1
    mov r8d, 2
    movabs rax, 0x140cba3a0
    call rax
    mov rdx, qword ptr [rsp + 0x20]
next:
    add rsi, 8
    dec edx
    jne slot
    add rsp, 0x28
    pop rsi
    pop rbx
    pop r9
    pop r8
    pop rdx
    pop rcx
    jmp qword ptr [rip]
    .quad 0x1480e8810
