.intel_syntax noprefix
.code64
start:
    movabs rax, 0x153737490
    cmp dword ptr [rax], 0
    jne original
    movabs rax, 0x153737400
    cmp byte ptr [rax], 0
    jne original
    mov byte ptr [rax], 1
    push rcx
    sub rsp, 0x20
    mov rdx, qword ptr [rax + 8]
    test rdx, rdx
    je created
    movabs rcx, 0x153737440
    mov qword ptr [rcx + 0x28], rdx
    or qword ptr [rcx + 0x18], 1
    call construct
    movabs rax, 0x153737400
    mov byte ptr [rax], 2
created:
    add rsp, 0x20
    pop rcx
original:
    movabs rax, 0x149083680
    jmp rax
construct:
    mov qword ptr [rsp + 8], rcx
    push rdi
    push r14
    push r15
    sub rsp, 0x30
    mov qword ptr [rsp + 0x20], -2
    mov qword ptr [rsp + 0x58], rbx
    mov qword ptr [rsp + 0x60], rbp
    mov qword ptr [rsp + 0x68], rsi
    mov rbx, rcx
    movabs rax, 0x1417c6dde
    jmp rax
