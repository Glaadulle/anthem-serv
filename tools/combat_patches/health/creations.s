.intel_syntax noprefix
.code64
serveur:
    mov rsp, r11
    pop r14
    jmp journal
client:
    add rsp, 0x50
    pop rdi
journal:
    mov ecx, 1
    movabs rdx, 0x153737c40
    lock xadd dword ptr [rdx], ecx
    and ecx, 63
    mov qword ptr [rdx + rcx*8 + 0x10], rax
    ret
